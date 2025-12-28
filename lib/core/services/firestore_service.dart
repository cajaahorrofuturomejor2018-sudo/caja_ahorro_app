import 'dart:math' as math;
import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/usuario.dart';
import '/models/deposito.dart';
import '/models/prestamo.dart';
import '../utils/logger.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Devuelve el nombre del campo en el documento `usuarios` que corresponde
  /// al tipo de depósito dado.
  /// Mapea tipos conocidos a sus campos concretos para evitar mezclar totales.
  String _fieldForTipo(String tipo) {
    switch (tipo) {
      case 'plazo_fijo':
        return 'total_plazos_fijos';
      case 'certificado':
        return 'total_certificados';
      case 'pago_prestamo':
        return 'total_prestamos';
      case 'ahorro':
      default:
        return 'total_ahorros';
    }
  }

  /// Calcula un reparto igualitario en centavos, devuelve lista de maps
  /// cada map: {'id_usuario': uid, 'monto': montoDouble}
  /// Garantiza que la suma de los montos devueltos == monto (dentro de centavos).
  static List<Map<String, dynamic>> computeEqualSplit(
    double monto,
    List<String> uids,
  ) {
    if (uids.isEmpty) return [];
    final totalCents = (monto * 100).round();
    final n = uids.length;
    final base = totalCents ~/ n;
    var remainder = totalCents % n;
    final List<Map<String, dynamic>> out = [];
    for (var i = 0; i < n; i++) {
      var cents = base;
      if (remainder > 0) {
        cents += 1;
        remainder -= 1;
      }
      out.add({'id_usuario': uids[i], 'monto': cents / 100.0});
    }
    return out;
  }

  // Utility: parse detalle_por_usuario defensively when elements may be Map or JSON-encoded String
  List<Map<String, dynamic>>? _parseDetalle(dynamic raw) {
    // Support both List and JSON-encoded String forms. Some clients may store
    // the detalle as a JSON string (e.g. '[{"id_usuario":"...","monto":10}]').
    dynamic source = raw;
    if (raw is String) {
      try {
        source = jsonDecode(raw);
      } catch (_) {
        // leave as String if decode fails; will return null below
      }
    }

    if (source is List) {
      final parsed = <Map<String, dynamic>>[];
      for (final e in source) {
        if (e is Map) {
          parsed.add(Map<String, dynamic>.from(e));
        } else if (e is String) {
          try {
            final dec = jsonDecode(e);
            if (dec is Map) parsed.add(Map<String, dynamic>.from(dec));
          } catch (_) {
            // ignore malformed element
          }
        }
      }
      return parsed;
    }
    return null;
  }

  // Obtener datos de usuario
  Future<Usuario?> getUsuario(String uid) async {
    AppLogger.info('getUsuario start', {'uid': uid});
    final snapshot = await _db.collection('usuarios').doc(uid).get();
    AppLogger.info('getUsuario result', {
      'uid': uid,
      'exists': snapshot.exists,
    });
    if (snapshot.exists) {
      return Usuario.fromFirestore(snapshot);
    }
    return null;
  }

  /// Obtener varios usuarios por una lista de ids (usa whereIn si la lista no está vacía).
  Future<List<Usuario>> getUsuariosByIds(List<String> uids) async {
    AppLogger.info('getUsuariosByIds start', {'count': uids.length});
    if (uids.isEmpty) return [];
    // Firestore limits whereIn to 10 items per query; fragment the list si necesario.
    final List<Usuario> result = [];
    const batchSize = 10;
    for (var i = 0; i < uids.length; i += batchSize) {
      final slice = uids.sublist(i, (i + batchSize).clamp(0, uids.length));
      final snap = await _db
          .collection('usuarios')
          .where(FieldPath.documentId, whereIn: slice)
          .get();
      AppLogger.info('getUsuariosByIds batch result', {
        'batchSize': snap.docs.length,
      });
      for (final d in snap.docs) {
        result.add(Usuario.fromFirestore(d));
      }
    }
    AppLogger.info('getUsuariosByIds end', {'resultCount': result.length});
    return result;
  }

  // Actualizar datos de usuario
  Future<void> updateUsuario(String uid, Map<String, dynamic> data) async {
    await _db.collection('usuarios').doc(uid).update(data);
  }

  // Registrar un nuevo depósito
  Future<void> addDeposito(Deposito deposito) async {
    // Prevent duplicate vouchers if configured
    try {
      AppLogger.info('addDeposito start', {
        'id_usuario': deposito.idUsuario,
        'voucherHash': deposito.voucherHash,
      });
      final cfg = await getConfiguracion();
      AppLogger.info('addDeposito configuracion', {'cfg': cfg});
      final voucherCfg =
          (cfg?['voucher_reuse_block'] ?? {}) as Map<String, dynamic>?;
      final bool voucherBlockEnabled =
          (voucherCfg?['enabled'] ?? false) as bool;
      final int voucherTtl = (voucherCfg?['ttl_days'] ?? 0) as int;
      final voucherHash = deposito.voucherHash ?? '';
      if (voucherBlockEnabled && voucherHash.isNotEmpty) {
        final fileHash = deposito.voucherFileHash ?? '';
        final isDup = await _isVoucherDuplicate(
          voucherHash,
          fileHash,
          voucherTtl,
          '',
        );
        AppLogger.info('addDeposito duplicateCheck', {'isDup': isDup});
        if (isDup) {
          throw Exception(
            'Voucher duplicado detectado (bloqueado por configuración)',
          );
        }
      }
    } catch (e, st) {
      // Log config errors and proceed to add (to avoid blocking on misconfig)
      AppLogger.warn('addDeposito: error leyendo config (se ignora)', {
        'error': e.toString(),
      });
      AppLogger.error('addDeposito stack', e, st);
    }
    final result = await _db.collection('depositos').add(deposito.toMap());
    AppLogger.info('addDeposito done', {'docId': result.id});
  }

  // Registrar un nuevo préstamo
  Future<void> addPrestamo(Prestamo prestamo) async {
    await _db.collection('prestamos').add(prestamo.toMap());
  }

  // Obtener depósitos del usuario
  Stream<List<Deposito>> getDepositos(String uid) {
    return _db
        .collection('depositos')
        .where('id_usuario', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Deposito.fromFirestore(doc)).toList(),
        );
  }

  // Obtener préstamos del usuario
  Stream<List<Prestamo>> getPrestamos(String uid) {
    return _db
        .collection('prestamos')
        .where('id_usuario', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Prestamo.fromFirestore(doc)).toList(),
        );
  }

  // Obtener depósitos una sola vez (no stream)
  Future<List<Deposito>> getDepositosOnce(String uid) async {
    final snapshot = await _db
        .collection('depositos')
        .where('id_usuario', isEqualTo: uid)
        .get();
    return snapshot.docs.map((d) => Deposito.fromFirestore(d)).toList();
  }

  // Obtener préstamos una sola vez (no stream)
  Future<List<Prestamo>> getPrestamosOnce(String uid) async {
    final snapshot = await _db
        .collection('prestamos')
        .where('id_usuario', isEqualTo: uid)
        .get();
    return snapshot.docs.map((d) => Prestamo.fromFirestore(d)).toList();
  }

  // --- Funciones administrativas ---

  /// Stream de todos los usuarios (para panel de administración).
  Stream<List<Usuario>> streamUsuarios() {
    return _db.collection('usuarios').snapshots().map((s) {
      AppLogger.info('streamUsuarios snapshot', {'count': s.docs.length});
      return s.docs.map((d) => Usuario.fromFirestore(d)).toList();
    });
  }

  /// Establece el rol del usuario.
  Future<void> setUserRole(String uid, String rol) async {
    await _db.collection('usuarios').doc(uid).update({'rol': rol});
  }

  /// Actualiza el estado del usuario ('activo' / 'inactivo').
  Future<void> setUserEstado(String uid, String estado) async {
    await _db.collection('usuarios').doc(uid).update({'estado': estado});
  }

  /// Stream de todos los depósitos (para revisión por admins).
  Stream<List<Deposito>> streamAllDepositos() {
    return _db
        .collection('depositos')
        .orderBy('fecha_registro', descending: true)
        .snapshots()
        .map((s) {
          AppLogger.info('streamAllDepositos snapshot', {
            'count': s.docs.length,
          });
          return s.docs.map((d) => Deposito.fromFirestore(d)).toList();
        });
  }

  /// Marca un depósito como validado / no validado.
  Future<void> setDepositoValidado(String depositoId, bool validado) async {
    await _db.collection('depositos').doc(depositoId).update({
      'validado': validado,
    });
    // Enviar notificación al solicitante
    try {
      final depSnap = await _db.collection('depositos').doc(depositoId).get();
      final depData = depSnap.data();
      final idUsuario = depData?['id_usuario'] as String?;
      if (idUsuario != null) {
        await sendNotification(
          idUsuario,
          'Depósito ${validado ? 'aprobado' : 'rechazado'}',
          'Tu depósito ha sido ${validado ? 'aprobado' : 'rechazado'}.',
          'aprobacion_deposito',
          '',
        );
      }
    } catch (_) {}
  }

  /// Obtener todos los usuarios una sola vez (para reportes agregados).
  Future<List<Usuario>> getAllUsuarios() async {
    final snapshot = await _db.collection('usuarios').get();
    return snapshot.docs.map((d) => Usuario.fromFirestore(d)).toList();
  }

  /// Obtener todos los depósitos una sola vez (para reportes agregados).
  Future<List<Deposito>> getAllDepositos() async {
    final snapshot = await _db.collection('depositos').get();
    return snapshot.docs.map((d) => Deposito.fromFirestore(d)).toList();
  }

  /// Alias para compatibilidad.
  Future<List<Deposito>> getAllDepositosOnce() async {
    return getAllDepositos();
  }

  /// Obtener todos los préstamos una sola vez (para reportes agregados).
  Future<List<Prestamo>> getAllPrestamos() async {
    final snapshot = await _db.collection('prestamos').get();
    return snapshot.docs.map((d) => Prestamo.fromFirestore(d)).toList();
  }

  /// Obtener totsales agregados (ej. sumas de depósitos y préstamos).
  Future<Map<String, double>> getAggregateTotals() async {
    double totalDepositos = 0.0;
    double totalPrestamos = 0.0;
    AppLogger.info('getAggregateTotals start');
    final depSnap = await _db.collection('depositos').get();
    for (final d in depSnap.docs) {
      final data = d.data();
      totalDepositos += (data['monto'] ?? 0).toDouble();
    }

    final preSnap = await _db.collection('prestamos').get();
    for (final p in preSnap.docs) {
      final data = p.data();
      totalPrestamos += (data['monto_aprobado'] ?? 0).toDouble();
    }

    return {
      'total_depositos': totalDepositos,
      'total_prestamos': totalPrestamos,
    };
  }

  // --- Configuración global ---

  /// Obtiene el documento de configuración (ej. 'configuracion/general').
  Future<Map<String, dynamic>?> getConfiguracion({
    String docId = 'general',
  }) async {
    // Try legacy path 'configuracion' -> docId
    final snap = await _db.collection('configuracion').doc(docId).get();
    if (snap.exists) return (snap.data() as Map<String, dynamic>);

    // Fallback to new collection 'configuracion_global' -> 'parametros'
    final snap2 = await _db
        .collection('configuracion_global')
        .doc('parametros')
        .get();
    if (snap2.exists) return (snap2.data() as Map<String, dynamic>);

    return null;
  }

  /// Crea o actualiza la configuración global.
  Future<void> setConfiguracion(
    Map<String, dynamic> data,
    String adminUid, {
    String docId = 'general',
  }) async {
    final payload = Map<String, dynamic>.from(data);
    payload['fecha_actualizacion'] = FieldValue.serverTimestamp();
    payload['actualizado_por'] = adminUid;
    await _db
        .collection('configuracion')
        .doc(docId)
        .set(payload, SetOptions(merge: true));
  }

  // --- Helpers para validación de vouchers ---

  /// Comprueba si existe un voucher con el mismo hash dentro del TTL (días).
  Future<bool> _isVoucherDuplicate(
    String voucherHash,
    String voucherFileHash,
    int ttlDays,
    String currentDepositId,
  ) async {
    AppLogger.info('_isVoucherDuplicate start', {
      'voucherHash': voucherHash,
      'voucherFileHash': voucherFileHash,
      'ttlDays': ttlDays,
    });
    // Check by voucher_hash if provided
    if (voucherHash.isNotEmpty) {
      final q = await _db
          .collection('depositos')
          .where('voucher_hash', isEqualTo: voucherHash)
          .get();
      AppLogger.info('_isVoucherDuplicate queryResult (hash)', {
        'found': q.docs.length,
      });
      for (final d in q.docs) {
        AppLogger.info('_isVoucherDuplicate checking doc (hash)', {
          'docId': d.id,
        });
        if (d.id == currentDepositId) continue;
        if (ttlDays > 0) {
          final ts = d.data()['fecha_registro'] as Timestamp?;
          if (ts != null) {
            final age = DateTime.now().difference(ts.toDate()).inDays;
            AppLogger.info('_isVoucherDuplicate age days', {'age': age});
            if (age <= ttlDays) return true;
          }
        } else {
          return true;
        }
      }
    }

    // Check by voucher_file_hash if provided
    if (voucherFileHash.isNotEmpty) {
      final q2 = await _db
          .collection('depositos')
          .where('voucher_file_hash', isEqualTo: voucherFileHash)
          .get();
      AppLogger.info('_isVoucherDuplicate queryResult (fileHash)', {
        'found': q2.docs.length,
      });
      for (final d in q2.docs) {
        AppLogger.info('_isVoucherDuplicate checking doc (fileHash)', {
          'docId': d.id,
        });
        if (d.id == currentDepositId) continue;
        if (ttlDays > 0) {
          final ts = d.data()['fecha_registro'] as Timestamp?;
          if (ts != null) {
            final age = DateTime.now().difference(ts.toDate()).inDays;
            AppLogger.info('_isVoucherDuplicate age days', {'age': age});
            if (age <= ttlDays) return true;
          }
        } else {
          return true;
        }
      }
    }

    return false;
  }

  /// Public wrapper to check if a voucher hash is considered duplicate based on
  /// current configuration. Returns true if duplicate and the configuration
  /// blocks reuse.
  Future<bool> isVoucherDuplicate(
    String voucherHash, {
    String voucherFileHash = '',
  }) async {
    try {
      final cfg = await getConfiguracion();
      final voucherCfg =
          (cfg?['voucher_reuse_block'] ?? {}) as Map<String, dynamic>?;
      final bool voucherBlockEnabled =
          (voucherCfg?['enabled'] ?? false) as bool;
      final int voucherTtl = (voucherCfg?['ttl_days'] ?? 0) as int;
      if (!voucherBlockEnabled) return false;
      return await _isVoucherDuplicate(
        voucherHash,
        voucherFileHash,
        voucherTtl,
        '',
      );
    } catch (_) {
      // If config can't be read, be permissive (do not block) to avoid
      // preventing legitimate deposits due to transient errors.
      return false;
    }
  }

  /// Calcula la multa (si aplica) de un depósito según configuración y fecha detectada.
  static double _computePenaltyForDeposit(
    Map<String, dynamic> depData,
    Map<String, dynamic>? config,
  ) {
    try {
      // If enforcement of voucher date is disabled, no penalty
      // Si no hay configuración explícita, por defecto ENFORCE en true para evitar que se salten multas
      final enforceDate = (config?['enforce_voucher_date'] ?? true) as bool;
      if (!enforceDate) return 0.0;

      // Determine detected deposit date (flexible parsing)
      final detectedRaw = depData['fecha_deposito_detectada'] as String?;
      DateTime? detectedDate;
      DateTime? tryParseFlexibleDate(String? raw) {
        if (raw == null || raw.isEmpty) return null;
        try {
          return DateTime.parse(raw);
        } catch (_) {}
        try {
          final s = raw.trim();
          final sep = s.contains('/') ? '/' : (s.contains('-') ? '-' : null);
          if (sep == null) return null;
          final parts = s
              .split(sep)
              .map((p) => p.replaceAll(RegExp(r'[^0-9]'), ''))
              .toList();
          if (parts.length < 3) return null;
          var a = int.tryParse(parts[0]) ?? 0;
          var b = int.tryParse(parts[1]) ?? 0;
          var c = int.tryParse(parts[2]) ?? 0;
          if (c < 100) c += 2000;
          if (a > 31) {
            return DateTime(a, b, c);
          }
          return DateTime(c, b, a);
        } catch (_) {
          return null;
        }
      }

      detectedDate = tryParseFlexibleDate(detectedRaw);
      if (detectedDate == null) {
        // fallback: if depData has fecha_deposito as Timestamp
        try {
          final ts = depData['fecha_deposito'] as Timestamp?;
          if (ts != null) detectedDate = ts.toDate();
        } catch (_) {}
      }
      if (detectedDate == null) return 0.0;

      final tipo = (depData['tipo'] as String?) ?? 'ahorro';
      final monto = (depData['monto'] ?? 0).toDouble();

      // Rule: monthly window is day 1..10 inclusive
      // Deadline is END OF DAY 10 (23:59:59) of the same month
      final dayOfMonth = detectedDate.day;

      // If deposit is on day 1-10, it's on time
      if (dayOfMonth <= 10) return 0.0;

      // Calculate days late starting from day 11 (00:00)
      // daysLate: day 11 = 1, day 12 = 2, ..., day 18 = 8, day 25 = 15, etc.
      final daysLate = dayOfMonth - 10;

      // Ahorro mensual: $1 per each started 7-day period of delay from day 11
      if (tipo == 'ahorro' || tipo == 'ahorro_voluntario') {
        // Formula: 1-7 days = 1 week, 8-14 days = 2 weeks, 15-21 days = 3 weeks, etc.
        final weeks = ((daysLate - 1) ~/ 7) + 1;
        final penaltyPerWeek =
            (config?['penalty_rules']?['ahorro_per_week'] ?? 1.0).toDouble();
        return (weeks * penaltyPerWeek) as double;
      }

      // Pago préstamo: apply percent of the cuota (we approximate cuota == monto del voucher)
      // 7% for days 1-15 late, 10% for days 16-30 late, then accumulates 10% per 30 days
      if (tipo == 'pago_prestamo') {
        // within 1-15 days late -> 7% of cuota
        if (daysLate <= 15) {
          return monto * 0.07;
        }
        // 16-30 days late -> 10% of cuota
        if (daysLate <= 30) {
          return monto * 0.10;
        }
        // beyond 30 days late: apply 10% per 30-day period (accumulate)
        if (daysLate > 30) {
          final periods = ((daysLate - 1) ~/ 30) + 1;
          return monto * 0.10 * periods;
        }
        return 0.0;
      }

      // Multas and other types: generic penalty configured as percent or fixed
      final pen = (config?['penalty'] ?? {}) as Map<String, dynamic>?;
      final pType = (pen?['type'] ?? 'percent').toString();
      final pVal = (pen?['value'] ?? 0).toDouble();
      if (pType == 'percent') return (monto * pVal / 100.0);
      return pVal;
    } catch (_) {
      return 0.0;
    }
  }

  /// Public wrapper for penalty computation (useful for tests).
  // Instance wrapper retained for backwards compatibility. Prefer static.
  double computePenaltyForDeposit(
    Map<String, dynamic> depData,
    Map<String, dynamic>? config,
  ) {
    return FirestoreService.computePenaltyForDepositStatic(depData, config);
  }

  /// Static helper usable in tests without Firebase initialization.
  static double computePenaltyForDepositStatic(
    Map<String, dynamic> depData,
    Map<String, dynamic>? config,
  ) {
    return _computePenaltyForDeposit(depData, config);
  }

  // --- Notificaciones y movimientos ---

  /// Obtiene el estado actual de la caja (document único 'caja/estado')
  Future<double> getCajaSaldo() async {
    AppLogger.info('getCajaSaldo start');
    final snap = await _db.collection('caja').doc('estado').get();
    AppLogger.info('getCajaSaldo read', {'exists': snap.exists});
    if (!snap.exists) return 0.0;
    final data = snap.data() as Map<String, dynamic>;
    final saldo = (data['saldo'] ?? 0).toDouble();
    AppLogger.info('getCajaSaldo value', {'saldo': saldo});
    return saldo;
  }

  /// Establece el saldo actual de la caja (admin action)
  Future<void> setCajaSaldo(double saldo, String adminUid) async {
    await _db.collection('caja').doc('estado').set({
      'saldo': saldo,
      'modificado_por': adminUid,
      'fecha_modificacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Admin agrega un aporte (depósito) directamente a un usuario.
  /// Este registro quedará marcado como validado y registrará el id_admin.
  Future<void> adminAddAporte({
    required String idUsuario,
    required String tipo,
    required double monto,
    String? descripcion,
    String? archivoUrl,
    required String adminUid,
  }) async {
    final doc = _db.collection('depositos').doc();
    final payload = {
      'id_usuario': idUsuario,
      'tipo': tipo,
      'monto': monto,
      'descripcion': descripcion ?? 'Aporte registrado por admin',
      'archivo_url': archivoUrl ?? '',
      'validado': true,
      'id_admin': adminUid,
      'fecha_deposito': FieldValue.serverTimestamp(),
      'fecha_registro': FieldValue.serverTimestamp(),
    };
    await doc.set(payload);

    // actualizar total del usuario
    final userRef = _db.collection('usuarios').doc(idUsuario);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final targetField = _fieldForTipo(tipo);
      final current = (data[targetField] ?? 0).toDouble();
      tx.update(userRef, {targetField: current + monto});

      // crear movimiento
      tx.set(_db.collection('movimientos').doc(), {
        'id_usuario': idUsuario,
        'tipo': tipo.isNotEmpty ? tipo : 'deposito',
        'referencia_id': doc.id,
        'monto': monto,
        'fecha': FieldValue.serverTimestamp(),
        'descripcion': descripcion ?? 'Aporte admin',
        'registrado_por': adminUid,
      });
    });
  }

  /// Enviar notificación manual creada por admin.
  Future<void> sendNotification(
    String userId,
    String titulo,
    String mensaje,
    String tipo,
    String adminUid,
  ) async {
    await _db.collection('notificaciones').add({
      'id_usuario': userId,
      'titulo': titulo,
      'mensaje': mensaje,
      'tipo': tipo,
      'estado': 'enviada',
      'fecha_envio': FieldValue.serverTimestamp(),
      'registrado_por': adminUid,
    });
  }

  /// Crea un movimiento contable (auditoría).
  Future<void> createMovimiento({
    required String idUsuario,
    required String tipo,
    required String referenciaId,
    required double monto,
    required String descripcion,
    String? registradoPor,
  }) async {
    await _db.collection('movimientos').add({
      'id_usuario': idUsuario,
      'tipo': tipo,
      'referencia_id': referenciaId,
      'monto': monto,
      'fecha': FieldValue.serverTimestamp(),
      'descripcion': descripcion,
      'registrado_por': registradoPor ?? '',
    });
  }

  Stream<List<Map<String, dynamic>>> streamMovimientos() {
    return _db
        .collection('movimientos')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  /// Stream de movimientos filtrados por usuario
  Stream<List<Map<String, dynamic>>> streamMovimientosForUser(String uid) {
    return _db
        .collection('movimientos')
        .where('id_usuario', isEqualTo: uid)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => Map<String, dynamic>.from(d.data() as Map))
              .toList(),
        );
  }

  /// Obtener depósito por id (datos completos) como map.
  Future<Map<String, dynamic>?> getDepositoById(String id) async {
    final snap = await _db.collection('depositos').doc(id).get();
    return snap.exists ? (snap.data() as Map<String, dynamic>) : null;
  }

  /// Obtener préstamo por id (datos completos) como map.
  Future<Map<String, dynamic>?> getPrestamoById(String id) async {
    final snap = await _db.collection('prestamos').doc(id).get();
    return snap.exists ? (snap.data() as Map<String, dynamic>) : null;
  }

  /// Crea un depósito a partir de un payload genérico y devuelve el id del documento.
  /// Útil para pruebas y simulador donde no se usa el modelo `Deposito`.
  Future<String> createDeposito(Map<String, dynamic> payload) async {
    final docRef = _db.collection('depositos').doc();
    // Normalizar payload: si no incluye timestamps, añadir serverTimestamp
    final p = Map<String, dynamic>.from(payload);
    if (!p.containsKey('fecha_registro')) {
      p['fecha_registro'] = FieldValue.serverTimestamp();
    }
    if (!p.containsKey('fecha_deposito')) {
      p['fecha_deposito'] = FieldValue.serverTimestamp();
    }
    // Prevent duplicate voucher when payload contains a voucher_hash and configuration blocks reuse
    try {
      final cfg = await getConfiguracion();
      final voucherCfg =
          (cfg?['voucher_reuse_block'] ?? {}) as Map<String, dynamic>?;
      final bool voucherBlockEnabled =
          (voucherCfg?['enabled'] ?? false) as bool;
      final int voucherTtl = (voucherCfg?['ttl_days'] ?? 0) as int;
      final voucherHash = (p['voucher_hash'] ?? '') as String? ?? '';
      final voucherFileHash = (p['voucher_file_hash'] ?? '') as String? ?? '';
      if (voucherBlockEnabled && voucherHash.isNotEmpty) {
        final isDup = await _isVoucherDuplicate(
          voucherHash,
          voucherFileHash,
          voucherTtl,
          '',
        );
        if (isDup) {
          throw Exception(
            'Voucher duplicado detectado (bloqueado por configuración)',
          );
        }
      }
    } catch (_) {}
    await docRef.set(p);
    return docRef.id;
  }

  // --- Aprobación transaccional de depósitos ---

  /// Aprueba o rechaza un depósito. Si aprueba, distribuye montos a usuarios en detalle_por_usuario
  /// y crea movimientos y actualiza los totales de usuario de forma transaccional.
  Future<void> approveDeposito(
    String depositoId,
    String adminUid, {
    required bool approve,
    String? observaciones,
    List<Map<String, dynamic>>? detalleOverride,
    // multasPorUsuario: mapa opcional {idUsuario: montoMulta}
    Map<String, double>? multasPorUsuario,
  }) async {
    AppLogger.info('approveDeposito start', {
      'depositoId': depositoId,
      'adminUid': adminUid,
      'approve': approve,
    });
    final depRef = _db.collection('depositos').doc(depositoId);

    // Load deposit snapshot to run pre-checks (duplicates / penalties)
    final depSnapPre = await depRef.get();
    if (!depSnapPre.exists) throw Exception('Depósito no encontrado');
    final depDataPre = depSnapPre.data() as Map<String, dynamic>;

    final config = await getConfiguracion();

    // Duplicate voucher detection
    try {
      final voucherCfg =
          (config?['voucher_reuse_block'] ?? {}) as Map<String, dynamic>?;
      final bool voucherBlockEnabled =
          (voucherCfg?['enabled'] ?? false) as bool;
      final int voucherTtl = (voucherCfg?['ttl_days'] ?? 0) as int;
      final String? voucherHash = depDataPre['voucher_hash'] as String?;
      final String? voucherFileHash =
          depDataPre['voucher_file_hash'] as String?;
      if (voucherBlockEnabled &&
          voucherHash != null &&
          voucherHash.isNotEmpty) {
        final isDup = await _isVoucherDuplicate(
          voucherHash,
          voucherFileHash ?? '',
          voucherTtl,
          depositoId,
        );
        if (isDup) {
          throw Exception(
            'Voucher duplicado detectado (bloqueado por configuración)',
          );
        }
      }
    } catch (_) {
      // if duplicate check fails due to query issues, let transaction proceed but log silently
    }

    // Compute penalty amount if applicable
    final multaMonto = _computePenaltyForDeposit(depDataPre, config);

    await _db.runTransaction((tx) async {
      final depSnap = await tx.get(depRef);
      if (!depSnap.exists) {
        throw Exception('Depósito no encontrado');
      }
      final depData = depSnap.data() as Map<String, dynamic>;

      // Si se rechaza, solo actualizar campos de revisión
      if (!approve) {
        tx.update(depRef, {
          'validado': false,
          'id_admin': adminUid,
          'observaciones': observaciones ?? '',
          'fecha_revision': FieldValue.serverTimestamp(),
        });
        return;
      }

      // Si se aprueba: determinamos el detalle de reparto
      final detalle =
          detalleOverride ?? _parseDetalle(depData['detalle_por_usuario']);

      // Validación de integridad: si hay detalle, la suma de montos no debe
      // exceder el monto total del depósito (permitimos sobrante).
      double montoSobrante = 0.0;
      if (detalle != null && detalle.isNotEmpty) {
        final montoTotal = (depData['monto'] ?? 0).toDouble();
        final totalCents = (montoTotal * 100).round();
        int sumDetalleCents = 0;
        for (final p in detalle) {
          final m = (p['monto'] ?? 0).toDouble();
          sumDetalleCents += ((m * 100).round() as int);
        }
        if (sumDetalleCents > totalCents) {
          throw Exception('La suma del detalle excede el monto del depósito');
        }
        final sobranteCents = totalCents - sumDetalleCents;
        montoSobrante = (sobranteCents / 100.0);
      }

      // --- Importante: Firestore requiere que todas las lecturas ocurran antes de las escrituras
      // Recolectamos los UIDs a leer primero, hacemos todos los tx.get(...) y solo después
      // aplicamos las actualizaciones (tx.update/tx.set).
      final Set<String> uidsToRead = {};
      if (detalle == null || detalle.isEmpty) {
        final idUsuario = depData['id_usuario'] as String?;
        if (idUsuario == null || idUsuario.isEmpty) {
          throw Exception('Depósito sin id_usuario');
        }
        uidsToRead.add(idUsuario);
        if (multaMonto > 0) {
          uidsToRead.add(idUsuario);
        }
      } else {
        for (final part in detalle) {
          final idUsuario = part['id_usuario'] as String?;
          if (idUsuario != null && idUsuario.isNotEmpty) {
            uidsToRead.add(idUsuario);
          }
        }
        if (multaMonto > 0) {
          final autorId = depData['id_usuario'] as String?;
          if (autorId != null && autorId.isNotEmpty) {
            uidsToRead.add(autorId);
          }
        }
      }

      // Incluir UIDs para multas por usuario si fueron pasadas
      if (multasPorUsuario != null && multasPorUsuario.isNotEmpty) {
        for (final uid in multasPorUsuario.keys) {
          if (uid.isNotEmpty) uidsToRead.add(uid);
        }
      }

      // Ejecutar todas las lecturas primero
      final Map<String, DocumentSnapshot> userSnaps = {};
      for (final uid in uidsToRead) {
        final snap = await tx.get(_db.collection('usuarios').doc(uid));
        userSnaps[uid] = snap;
      }

      // Ahora aplicar las escrituras basadas en los documentos leídos
      if (detalle == null || detalle.isEmpty) {
        final idUsuario = depData['id_usuario'] as String?;
        final monto = (depData['monto'] ?? 0).toDouble();
        final userSnap = userSnaps[idUsuario];
        if (userSnap == null || !userSnap.exists) {
          throw Exception('Usuario del depósito no encontrado');
        }
        final userData = userSnap.data() as Map<String, dynamic>;
        final depTipo = (depData['tipo'] as String?) ?? 'ahorro';
        final targetField = _fieldForTipo(depTipo);
        final current = (userData[targetField] ?? 0).toDouble();
        tx.update(_db.collection('usuarios').doc(idUsuario), {
          targetField: current + monto,
        });

        final movimientoTipo = depTipo.isNotEmpty ? depTipo : 'deposito';
        tx.set(_db.collection('movimientos').doc(), {
          'id_usuario': idUsuario,
          'tipo': movimientoTipo,
          'referencia_id': depositoId,
          'monto': monto,
          'fecha': FieldValue.serverTimestamp(),
          'descripcion': depData['descripcion'] ?? 'Depósito aprobado',
          'registrado_por': adminUid,
        });

        if (multaMonto > 0) {
          // Las multas se dirigen al saldo de la caja (caja/estado).
          final cajaRef = _db.collection('caja').doc('estado');
          final cajaSnap = await tx.get(cajaRef);
          double currentCaja = 0.0;
          if (cajaSnap.exists) {
            final cdata = cajaSnap.data() as Map<String, dynamic>;
            currentCaja = (cdata['saldo'] ?? 0).toDouble();
          }
          tx.update(cajaRef, {'saldo': currentCaja + multaMonto});

          // Registrar movimiento de multa para auditoría (asociado al autor)
          final autorId = depData['id_usuario'] as String?;
          tx.set(_db.collection('movimientos').doc(), {
            'id_usuario': autorId ?? '',
            'tipo': 'multa',
            'referencia_id': depositoId,
            'monto': multaMonto,
            'fecha': FieldValue.serverTimestamp(),
            'descripcion': 'Multa por depósito tardío',
            'registrado_por': adminUid,
          });
        }
      } else {
        for (final part in detalle) {
          final idUsuario = part['id_usuario'] as String?;
          final monto = (part['monto'] ?? 0).toDouble();
          if (idUsuario == null || idUsuario.isEmpty) continue;
          final userSnap = userSnaps[idUsuario];
          if (userSnap == null || !userSnap.exists) continue;
          final userData = userSnap.data() as Map<String, dynamic>;
          final partTipo =
              (part['tipo'] as String?) ??
              (depData['tipo'] as String?) ??
              'ahorro';
          final targetField = _fieldForTipo(partTipo);
          final current = (userData[targetField] ?? 0).toDouble();
          tx.update(_db.collection('usuarios').doc(idUsuario), {
            targetField: current + monto,
          });

          final movimientoTipo = partTipo.isNotEmpty ? partTipo : 'deposito';
          tx.set(_db.collection('movimientos').doc(), {
            'id_usuario': idUsuario,
            'tipo': movimientoTipo,
            'referencia_id': depositoId,
            'monto': monto,
            'fecha': FieldValue.serverTimestamp(),
            'descripcion':
                depData['descripcion'] ?? 'Depósito aprobado (repartido)',
            'registrado_por': adminUid,
          });
        }

        // Aplicar multas por usuario especificadas por el admin (si las hay)
        // Acumular multas que deben ir a la caja y registrar movimientos de multa
        double multasSum = 0.0;
        if (multasPorUsuario != null && multasPorUsuario.isNotEmpty) {
          for (final entry in multasPorUsuario.entries) {
            final targetUid = entry.key;
            final multa = entry.value;
            if (multa <= 0) continue;
            multasSum += multa;

            // Movimiento contable por multa (audit trail)
            tx.set(_db.collection('movimientos').doc(), {
              'id_usuario': targetUid,
              'tipo': 'multa',
              'referencia_id': depositoId,
              'monto': multa,
              'fecha': FieldValue.serverTimestamp(),
              'descripcion': 'Multa aplicada por admin durante revisión',
              'registrado_por': adminUid,
            });
          }
        }

        if (multaMonto > 0) {
          multasSum += multaMonto;
          final autorId = depData['id_usuario'] as String?;
          tx.set(_db.collection('movimientos').doc(), {
            'id_usuario': autorId ?? '',
            'tipo': 'multa',
            'referencia_id': depositoId,
            'monto': multaMonto,
            'fecha': FieldValue.serverTimestamp(),
            'descripcion': 'Multa por depósito tardío',
            'registrado_por': adminUid,
          });
        }

        if (multasSum > 0) {
          final cajaRef = _db.collection('caja').doc('estado');
          final cajaSnap2 = await tx.get(cajaRef);
          double currentCaja2 = 0.0;
          if (cajaSnap2.exists) {
            final cdata2 = cajaSnap2.data() as Map<String, dynamic>;
            currentCaja2 = (cdata2['saldo'] ?? 0).toDouble();
          }
          tx.update(cajaRef, {'saldo': currentCaja2 + multasSum});
        }
      }

      // Finalmente actualizar el depósito (incluye multa y monto_sobrante si aplica)
      final updatePayload = {
        'validado': true,
        'id_admin': adminUid,
        'observaciones': observaciones ?? '',
        'fecha_revision': FieldValue.serverTimestamp(),
      };
      if (multaMonto > 0) {
        updatePayload['multa_monto'] = multaMonto;
      }
      if (montoSobrante > 0) {
        updatePayload['monto_sobrante'] = montoSobrante;
      }
      tx.update(depRef, updatePayload);
    });
    // Después de la transacción, enviar notificaciones a los usuarios afectados.
    try {
      final afterSnap = await _db.collection('depositos').doc(depositoId).get();
      final afterData = afterSnap.data();
      if (afterData != null) {
        final detalle = _parseDetalle(afterData['detalle_por_usuario']);
        if (detalle == null || detalle.isEmpty) {
          final idUsuario = afterData['id_usuario'] as String?;
          if (idUsuario != null) {
            await sendNotification(
              idUsuario,
              'Depósito revisado',
              'Tu depósito ha sido ${afterData['validado'] == true ? 'aprobado' : 'rechazado'}.',
              'aprobacion',
              adminUid,
            );
          }
        } else {
          for (final p in detalle) {
            final idUsuario = p['id_usuario'] as String?;
            if (idUsuario != null) {
              await sendNotification(
                idUsuario,
                'Depósito revisado',
                'Tu depósito ha sido ${afterData['validado'] == true ? 'aprobado' : 'rechazado'}.',
                'aprobacion',
                adminUid,
              );
            }
          }
          // Si hay monto sobrante, notificar al solicitante (autor) sobre el crédito restante
          final sobrante = (afterData['monto_sobrante'] ?? 0).toDouble();
          if (sobrante > 0) {
            final autor = afterData['id_usuario'] as String?;
            if (autor != null && autor.isNotEmpty) {
              await sendNotification(
                autor,
                'Depósito procesado — sobrante registrado',
                'Se ha registrado un sobrante de \$${sobrante.toStringAsFixed(2)} para este depósito. Puedes aplicarlo en futuros registros.',
                'sobrante',
                adminUid,
              );
            }
          }
        }
      }
    } catch (e, st) {
      AppLogger.error('approveDeposito error', e, st);
      rethrow;
    }
  }

  /// Admin: crear un depósito con detalle (reparto) y aprobarlo de forma automática.
  Future<void> adminCreateDepositoWithDetalle({
    required String tipo,
    required double monto,
    String? descripcion,
    required List<Map<String, dynamic>> detalle,
    required String adminUid,
  }) async {
    // Validación: el detalle debe sumar exactamente el monto (en centavos)
    final totalCents = (monto * 100).round();
    int sumDetalleCents = 0;
    for (final p in detalle) {
      final m = (p['monto'] ?? 0).toDouble();
      sumDetalleCents += ((m * 100).round() as int);
    }
    if (sumDetalleCents != totalCents) {
      throw Exception(
        'Detalle no suma el monto total (adminCreateDepositoWithDetalle)',
      );
    }
    final docRef = _db.collection('depositos').doc();
    final payload = {
      'id_usuario': '',
      'tipo': tipo,
      'monto': monto,
      'descripcion': descripcion ?? 'Depósito creado por admin',
      'detalle_por_usuario': detalle,
      'archivo_url': '',
      'validado': false,
      'id_admin': adminUid,
      'fecha_deposito': FieldValue.serverTimestamp(),
      'fecha_registro': FieldValue.serverTimestamp(),
    };
    await docRef.set(payload);

    // aprobar y distribuir inmediatamente
    await approveDeposito(
      docRef.id,
      adminUid,
      approve: true,
      detalleOverride: detalle,
    );
  }

  // --- Familias (grupos familiares) ---

  Stream<List<Map<String, dynamic>>> streamFamilias() {
    return _db.collection('familias').snapshots().map((s) {
      AppLogger.info('streamFamilias snapshot', {'count': s.docs.length});
      return s.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data() as Map);
        m['id'] = d.id;
        return m;
      }).toList();
    });
  }

  Future<void> createFamilia(Map<String, dynamic> payload) async {
    payload['fecha_creacion'] = FieldValue.serverTimestamp();
    await _db.collection('familias').add(payload);
  }

  Future<void> updateFamilia(String id, Map<String, dynamic> payload) async {
    await _db
        .collection('familias')
        .doc(id)
        .set(payload, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getFamiliaById(String id) async {
    final snap = await _db.collection('familias').doc(id).get();
    return snap.exists ? (snap.data() as Map<String, dynamic>) : null;
  }

  // --- Préstamos ---

  Stream<List<Prestamo>> streamPrestamos() {
    return _db
        .collection('prestamos')
        .orderBy('fecha_registro', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Prestamo.fromFirestore(d)).toList());
  }

  /// Stream de notificaciones para un usuario específico.
  Stream<List<Map<String, dynamic>>> streamNotificacionesParaUsuario(
    String uid,
  ) {
    // Some Firestore deployments may require a composite index for a
    // where(id_usuario) + orderBy(fecha_envio) query. To be resilient and
    // avoid a hard failure in clients that don't have that index created,
    // we fetch the snapshots with the equality filter only and then sort
    // client-side by fecha_envio (descending).
    return _db
        .collection('notificaciones')
        .where('id_usuario', isEqualTo: uid)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => Map<String, dynamic>.from(d.data() as Map))
              .toList();
          // Sort client-side by fecha_envio (most recent first)
          list.sort((a, b) {
            try {
              final ta = a['fecha_envio'] as Timestamp?;
              final tb = b['fecha_envio'] as Timestamp?;
              final da = ta?.toDate().millisecondsSinceEpoch ?? 0;
              final db = tb?.toDate().millisecondsSinceEpoch ?? 0;
              return db.compareTo(da);
            } catch (_) {
              return 0;
            }
          });
          return list;
        });
  }

  Future<String> requestPrestamo(Map<String, dynamic> payload) async {
    payload['fecha_registro'] = FieldValue.serverTimestamp();
    payload['estado'] = 'pendiente';
    final ref = await _db.collection('prestamos').add(payload);
    return ref.id;
  }

  /// Crea una solicitud de préstamo y opcionalmente sube el PDF de certificado al Storage.
  Future<String> createPrestamoWithCert({
    required String idUsuario,
    required double montoSolicitado,
    required double interes,
    required int plazoMeses,
    String? certificadoLocalPath,
    String? tipo,
  }) async {
    String? certificadoUrl;
    final docRef = _db.collection('prestamos').doc();
    if (certificadoLocalPath != null && certificadoLocalPath.isNotEmpty) {
      final storage = FirebaseStorage.instance;
      final fileRef = storage.ref('prestamos/${docRef.id}/certificado.pdf');
      final file = File(certificadoLocalPath);
      await fileRef.putFile(file);
      certificadoUrl = await fileRef.getDownloadURL();
    }
    final payload = {
      'id_usuario': idUsuario,
      'monto_solicitado': montoSolicitado,
      'tipo': tipo ?? 'consumo',
      'interes': interes,
      'plazo_meses': plazoMeses,
      'estado': 'pendiente',
      'certificado_pdf_url': certificadoUrl,
      'fecha_registro': FieldValue.serverTimestamp(),
    };
    await docRef.set(payload);
    return docRef.id;
  }

  /// Aprueba o rechaza un préstamo y si aprueba calcula cuotas y crea movimiento.
  Future<void> approvePrestamo(
    String prestamoId,
    String adminUid, {
    required bool approve,
    double? montoAprobado,
    double? interes,
    int? plazoMeses,
    String? observaciones,
  }) async {
    final preRef = _db.collection('prestamos').doc(prestamoId);
    await _db.runTransaction((tx) async {
      final preSnap = await tx.get(preRef);
      if (!preSnap.exists) {
        throw Exception('Préstamo no encontrado');
      }
      final data = preSnap.data() as Map<String, dynamic>;
      if (!approve) {
        tx.update(preRef, {
          'estado': 'rechazado',
          'id_admin_aprobador': adminUid,
          'observaciones': observaciones ?? '',
          'fecha_revision': FieldValue.serverTimestamp(),
        });
        return;
      }

      final montoSolicitud = (data['monto_solicitado'] ?? 0).toDouble();
      final montoFinal = montoAprobado ?? montoSolicitud;
      final int intPlazo =
          plazoMeses ?? ((data['plazo_meses'] as num?)?.toInt() ?? 12);
      final rate = (interes ?? (data['interes'] ?? 0)).toDouble() / 100.0;

      // Calcula cuota mensual (fórmula simple de amortización)
      double cuota = 0.0;
      if (rate > 0) {
        final monthlyRate = rate / 12.0;
        final denom = 1 - (1 / math.pow(1 + monthlyRate, intPlazo).toDouble());
        cuota = denom != 0
            ? (montoFinal * monthlyRate / denom)
            : montoFinal / intPlazo;
      } else {
        cuota = montoFinal / intPlazo;
      }

      final fechaInicio = DateTime.now();
      final fechaFin = DateTime(
        fechaInicio.year,
        fechaInicio.month + intPlazo,
        fechaInicio.day,
      );
      final primeraCuota = DateTime(
        fechaInicio.year,
        fechaInicio.month + 1,
        fechaInicio.day,
      );

      // Marcar como activo y preparar estado para cobro de cuotas
      tx.update(preRef, {
        'estado': 'activo',
        'id_admin_aprobador': adminUid,
        'monto_aprobado': montoFinal,
        'cuota_mensual': cuota,
        'interes': (interes ?? data['interes'] ?? 0),
        'plazo_meses': intPlazo,
        'fecha_inicio': FieldValue.serverTimestamp(),
        'fecha_fin': Timestamp.fromDate(fechaFin),
        'observaciones': observaciones ?? '',
        'fecha_aprobacion': FieldValue.serverTimestamp(),
        'saldo_pendiente': montoFinal,
        'meses_restantes': intPlazo,
        'proxima_fecha_cuota': Timestamp.fromDate(primeraCuota),
      });

      // crear movimiento contable por desembolso
      tx.set(_db.collection('movimientos').doc(), {
        'id_usuario': data['id_usuario'] ?? '',
        'tipo': 'prestamo_desembolso',
        'referencia_id': prestamoId,
        'monto': montoFinal,
        'fecha': FieldValue.serverTimestamp(),
        'descripcion': 'Desembolso préstamo aprobado',
        'registrado_por': adminUid,
      });
      // actualizar agregados del usuario: total_prestamos
      final usuarioId = data['id_usuario'] as String?;
      if (usuarioId != null && usuarioId.isNotEmpty) {
        final usuarioRef = _db.collection('usuarios').doc(usuarioId);
        final usuarioSnap = await tx.get(usuarioRef);
        if (usuarioSnap.exists) {
          final usuarioData = usuarioSnap.data() as Map<String, dynamic>;
          final currentPrestamos = (usuarioData['total_prestamos'] ?? 0)
              .toDouble();
          tx.update(usuarioRef, {
            'total_prestamos': currentPrestamos + montoFinal,
          });
        }
      }
    });
  }

  /// Sube un contrato PDF al storage y aprueba el préstamo en una transacción.
  Future<void> uploadContratoPdfAndApprove({
    required String prestamoId,
    required String adminUid,
    required String localContratoPath,
    required double montoAprobado,
    String? observaciones,
  }) async {
    // subir archivo
    final storage = FirebaseStorage.instance;
    final contratoRef = storage.ref('prestamos/$prestamoId/contrato.pdf');
    final file = File(localContratoPath);
    await contratoRef.putFile(file);
    final contratoUrl = await contratoRef.getDownloadURL();

    final preRef = _db.collection('prestamos').doc(prestamoId);
    await _db.runTransaction((tx) async {
      final preSnap = await tx.get(preRef);
      if (!preSnap.exists) throw Exception('Préstamo no encontrado');
      final data = preSnap.data() as Map<String, dynamic>;

      final intPlazo = (data['plazo_meses'] as num?)?.toInt() ?? 12;
      final rate = (data['interes'] ?? 0).toDouble() / 100.0;
      final fechaInicio = DateTime.now();
      final primeraCuota = DateTime(
        fechaInicio.year,
        fechaInicio.month + 1,
        fechaInicio.day,
      );

      // calcular cuota (simplificado)
      double cuota = montoAprobado / intPlazo;
      if (rate > 0) {
        final monthlyRate = rate / 12.0;
        final denom = 1 - (1 / math.pow(1 + monthlyRate, intPlazo).toDouble());
        cuota = denom != 0
            ? (montoAprobado * monthlyRate / denom)
            : montoAprobado / intPlazo;
      }

      tx.update(preRef, {
        'estado': 'activo',
        'id_admin_aprobador': adminUid,
        'monto_aprobado': montoAprobado,
        'cuota_mensual': cuota,
        'contrato_pdf_url': contratoUrl,
        'observaciones': observaciones ?? '',
        'fecha_aprobacion': FieldValue.serverTimestamp(),
        'proxima_fecha_cuota': Timestamp.fromDate(primeraCuota),
      });

      // crear movimiento contable
      tx.set(_db.collection('movimientos').doc(), {
        'id_usuario': data['id_usuario'] ?? '',
        'tipo': 'prestamo_desembolso',
        'referencia_id': prestamoId,
        'monto': montoAprobado,
        'fecha': FieldValue.serverTimestamp(),
        'descripcion': 'Desembolso préstamo aprobado (contrato subido)',
        'registrado_por': adminUid,
      });
    });

    // notificar al usuario
    final snap = await preRef.get();
    final uid = snap.data()?['id_usuario'];
    if (uid != null) {
      await _db.collection('notificaciones').add({
        'id_usuario': uid,
        'titulo': 'Préstamo aprobado y contrato disponible',
        'mensaje':
            'Su préstamo ha sido aprobado y puede descargar el contrato desde la app.',
        'tipo': 'aprobacion',
        'estado': 'enviada',
        'fecha_envio': FieldValue.serverTimestamp(),
        'accion_relacionada': prestamoId,
      });
    }
  }

  Future<void> addPagoPrestamo(
    String prestamoId,
    Map<String, dynamic> pago,
  ) async {
    final preRef = _db.collection('prestamos').doc(prestamoId);
    await _db.runTransaction((tx) async {
      final preSnap = await tx.get(preRef);
      if (!preSnap.exists) throw Exception('Préstamo no encontrado');
      final data = preSnap.data() as Map<String, dynamic>;
      final historial = List<Map<String, dynamic>>.from(
        data['historial_pagos'] ?? [],
      );
      historial.add(pago);

      // calcular nuevo saldo y meses restantes
      final montoAprobado = (data['monto_aprobado'] ?? 0).toDouble();
      final cuota = (data['cuota_mensual'] ?? 0).toDouble();
      double totalPagado = 0.0;
      for (final h in historial) {
        totalPagado += (h['monto'] ?? 0).toDouble();
      }
      final saldoPendiente = (montoAprobado - totalPagado).clamp(
        0.0,
        montoAprobado,
      );
      int mesesRestantes = 0;
      if (cuota > 0) {
        mesesRestantes = (saldoPendiente / cuota).ceil();
      }

      final now = DateTime.now();
      final proximaCuota = DateTime(now.year, now.month + 1, now.day);

      final updates = <String, dynamic>{
        'historial_pagos': historial,
        'saldo_pendiente': saldoPendiente,
        'meses_restantes': mesesRestantes,
        'fecha_ultimo_pago': FieldValue.serverTimestamp(),
        'proxima_fecha_cuota': Timestamp.fromDate(proximaCuota),
      };

      if (saldoPendiente <= 0.001) {
        updates['estado'] = 'cancelado';
        updates['fecha_cancelacion'] = FieldValue.serverTimestamp();
      }

      tx.update(preRef, updates);

      // crear movimiento
      tx.set(_db.collection('movimientos').doc(), {
        'id_usuario': data['id_usuario'] ?? '',
        'tipo': 'pago_prestamo',
        'referencia_id': prestamoId,
        'monto': pago['monto'] ?? 0,
        'fecha': FieldValue.serverTimestamp(),
        'descripcion': pago['descripcion'] ?? 'Pago préstamo',
        'registrado_por': pago['registrado_por'] ?? '',
      });
    });
  }
}
