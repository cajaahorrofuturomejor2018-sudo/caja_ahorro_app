import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

/// Servicio para verificar y aplicar multas automáticamente
/// Se ejecuta al iniciar sesión del usuario para asegurar que las multas
/// por ahorros faltantes y préstamos vencidos se apliquen correctamente
class PenaltyCheckService {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Obtiene el documento del usuario soportando ambas colecciones
  /// ('usuarios' y legacy 'users'). Esto evita que las multas se escriban en
  /// la colección equivocada y no se reflejen en la app.
  Future<DocumentReference<Map<String, dynamic>>?> _resolveUserDoc(
    String userId,
  ) async {
    final usuariosRef = _db.collection('usuarios').doc(userId);
    final usuariosSnap = await usuariosRef.get();
    if (usuariosSnap.exists) return usuariosRef;

    final legacyRef = _db.collection('users').doc(userId);
    final legacySnap = await legacyRef.get();
    if (legacySnap.exists) return legacyRef;

    return null;
  }

  /// Verifica y aplica todas las multas pendientes para un usuario
  /// Retorna el total de multas aplicadas
  Future<double> checkAndApplyPenalties(String userId) async {
    double totalPenaltiesApplied = 0.0;

    try {
      // 1. Verificar multa por ahorro mensual faltante
      final ahorroPenalty = await _checkMissingMonthlyDeposit(userId);
      totalPenaltiesApplied += ahorroPenalty;

      // 2. Verificar multas por préstamos vencidos
      final prestamoPenalty = await _checkOverdueLoans(userId);
      totalPenaltiesApplied += prestamoPenalty;

      // 3. Actualizar total_multas del usuario si hay multas nuevas
      if (totalPenaltiesApplied > 0) {
        await _updateUserTotalPenalties(userId, totalPenaltiesApplied);
      }

      return totalPenaltiesApplied;
    } catch (e) {
      // Error verificando multas (silencioso para no interrumpir login)
      return 0.0;
    }
  }

  /// Verifica si falta el ahorro mensual después del día 10
  Future<double> _checkMissingMonthlyDeposit(String userId) async {
    try {
      final now = DateTime.now();

      // Solo aplicar multa después del día 10
      if (now.day <= 10) {
        return 0.0;
      }

      // Obtener el primer y último día del mes actual
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Buscar depósitos de "ahorro" del mes actual
      final depositsSnapshot = await _db
          .collection('depositos')
          .where('id_usuario', isEqualTo: userId)
          .where('tipo', isEqualTo: 'ahorro')
          .where('estado', isEqualTo: 'aprobado')
          .get();

      // Filtrar depósitos del mes actual
      bool hasMonthlyDeposit = false;
      for (final doc in depositsSnapshot.docs) {
        final data = doc.data();
        final fechaDeposito = (data['fecha_deposito'] as Timestamp?)?.toDate();

        if (fechaDeposito != null &&
            fechaDeposito.isAfter(
              firstDayOfMonth.subtract(const Duration(days: 1)),
            ) &&
            fechaDeposito.isBefore(
              lastDayOfMonth.add(const Duration(days: 1)),
            )) {
          hasMonthlyDeposit = true;
          break;
        }
      }

      // Si no hay depósito de ahorro este mes, aplicar multa
      if (!hasMonthlyDeposit) {
        // Calcular multa: $1 por cada semana completa después del día 10
        final daysLate = now.day - 10;
        final weeks = ((daysLate - 1) ~/ 7) + 1;

        // Obtener configuración de multa (por defecto $1 por semana)
        final config = await _firestoreService.getConfiguracion();
        final penaltyPerWeek =
            (config?['penalty_rules']?['ahorro_per_week'] ?? 1.0).toDouble();

        final penaltyAmount = (weeks * penaltyPerWeek).toDouble();

        // Registrar la multa en Firestore
        await _registerPenalty(
          userId: userId,
          amount: penaltyAmount,
          reason: 'Falta de ahorro mensual - ${now.month}/${now.year}',
          type: 'ahorro_faltante',
        );

        return penaltyAmount;
      }

      return 0.0;
    } catch (e) {
      // Error verificando ahorro mensual
      return 0.0;
    }
  }

  /// Verifica préstamos vencidos y aplica multas correspondientes
  Future<double> _checkOverdueLoans(String userId) async {
    try {
      final now = DateTime.now();
      double totalPenalty = 0.0;

      // Obtener préstamos activos del usuario
      final prestamosSnapshot = await _db
          .collection('prestamos')
          .where('id_usuario', isEqualTo: userId)
          .where('estado', isEqualTo: 'activo')
          .get();

      for (final doc in prestamosSnapshot.docs) {
        final data = doc.data();
        final prestamoId = doc.id;

        // Obtener fecha de siguiente cuota
        DateTime? proximaFecha = (data['proxima_fecha_cuota'] as Timestamp?)
            ?.toDate();

        // Si no hay proxima_fecha_cuota, inicializarla a un mes después de la
        // fecha de inicio o de hoy. Esto evita que los préstamos queden sin
        // calendario y nunca generen multas ni cobros.
        if (proximaFecha == null) {
          final fechaInicio =
              (data['fecha_inicio'] as Timestamp?)?.toDate() ?? now;
          proximaFecha = DateTime(
            fechaInicio.year,
            fechaInicio.month + 1,
            fechaInicio.day,
          );

          await _db.collection('prestamos').doc(prestamoId).update({
            'proxima_fecha_cuota': Timestamp.fromDate(proximaFecha),
          });
        }

        if (now.isAfter(proximaFecha)) {
          // Calcular días de retraso
          final daysLate = now.difference(proximaFecha).inDays;

          if (daysLate > 0) {
            // Obtener monto de la cuota (campo guardado como cuota_mensual)
            final montoCuota =
                (data['cuota_mensual'] ?? data['monto_cuota'] ?? 0).toDouble();

            // Aplicar reglas de multa por préstamo:
            // 1-15 días: 7% de la cuota
            // 16-30 días: 10% de la cuota
            // Más de 30 días: 10% por cada período de 30 días
            double penaltyAmount = 0.0;

            if (daysLate <= 15) {
              penaltyAmount = montoCuota * 0.07;
            } else if (daysLate <= 30) {
              penaltyAmount = montoCuota * 0.10;
            } else {
              final periods = ((daysLate - 1) ~/ 30) + 1;
              penaltyAmount = montoCuota * 0.10 * periods;
            }

            // Verificar si ya se aplicó esta multa (evitar duplicados)
            Query<Map<String, dynamic>> penaltyQuery = _db
                .collection('multas')
                .where('id_usuario', isEqualTo: userId)
                .where('mes', isEqualTo: now.month)
                .where('anio', isEqualTo: now.year)
                .where('tipo', isEqualTo: 'prestamo_vencido');

            // Si la multa es por préstamo, filtrar por referencia para
            // permitir varias multas en distintos préstamos del mismo mes.
            penaltyQuery = penaltyQuery.where(
              'referencia_prestamo',
              isEqualTo: prestamoId,
            );

            final existingPenalty = await penaltyQuery.get();

            if (existingPenalty.docs.isEmpty && penaltyAmount > 0) {
              // Registrar multa
              await _registerPenalty(
                userId: userId,
                amount: penaltyAmount,
                reason: 'Préstamo vencido - $daysLate días de retraso',
                type: 'prestamo_vencido',
                referenciaId: prestamoId,
              );

              totalPenalty += penaltyAmount;
            }
          }
        }
      }

      return totalPenalty;
    } catch (e) {
      // Error verificando préstamos
      return 0.0;
    }
  }

  /// Registra una multa en la colección de multas y crea movimiento
  Future<void> _registerPenalty({
    required String userId,
    required double amount,
    required String reason,
    required String type,
    String? referenciaId,
  }) async {
    try {
      final now = DateTime.now();

      // Verificar si ya existe esta multa para evitar duplicados
      Query<Map<String, dynamic>> query = _db
          .collection('multas')
          .where('id_usuario', isEqualTo: userId)
          .where('tipo', isEqualTo: type)
          .where('mes', isEqualTo: now.month)
          .where('anio', isEqualTo: now.year);

      if (referenciaId != null) {
        query = query.where('referencia_prestamo', isEqualTo: referenciaId);
      }

      final existing = await query.get();

      if (existing.docs.isNotEmpty) {
        // Ya existe, no duplicar
        return;
      }

      // Crear registro de multa
      await _db.collection('multas').add({
        'id_usuario': userId,
        'monto': amount,
        'motivo': reason,
        'tipo': type,
        'referencia_prestamo': referenciaId,
        'fecha_aplicacion': Timestamp.now(),
        'mes': now.month,
        'anio': now.year,
        'estado': 'pendiente', // 'pendiente' o 'pagada'
      });

      // Crear movimiento en la caja (las multas van a la caja)
      await _db.collection('movimientos').add({
        'tipo': 'multa',
        'id_usuario': userId,
        'monto': amount,
        'descripcion': reason,
        'fecha': Timestamp.now(),
        'mes': now.month,
        'anio': now.year,
      });

      // Multa registrada exitosamente
    } catch (e) {
      // Error registrando multa
    }
  }

  /// Actualiza el total de multas del usuario sumando las nuevas
  Future<void> _updateUserTotalPenalties(
    String userId,
    double newPenalties,
  ) async {
    try {
      final userRef = await _resolveUserDoc(userId);
      if (userRef == null) {
        return; // No se encontró el usuario en ninguna colección conocida
      }

      await _db.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) return;

        final currentTotal = (userDoc.data()?['total_multas'] ?? 0).toDouble();
        final newTotal = currentTotal + newPenalties;

        transaction.update(userRef, {'total_multas': newTotal});
      });

      // Total de multas actualizado
    } catch (e) {
      // Error actualizando total de multas
    }
  }

  /// Obtiene el total de multas pendientes del usuario
  Future<double> getPendingPenalties(String userId) async {
    try {
      final multasSnapshot = await _db
          .collection('multas')
          .where('id_usuario', isEqualTo: userId)
          .where('estado', isEqualTo: 'pendiente')
          .get();

      double total = 0.0;
      for (final doc in multasSnapshot.docs) {
        total += (doc.data()['monto'] ?? 0).toDouble();
      }

      return total;
    } catch (e) {
      // Error obteniendo multas pendientes
      return 0.0;
    }
  }

  /// Marca una multa como pagada
  Future<void> markPenaltyAsPaid(String multaId) async {
    try {
      await _db.collection('multas').doc(multaId).update({
        'estado': 'pagada',
        'fecha_pago': Timestamp.now(),
      });
    } catch (e) {
      // Error marcando multa como pagada
    }
  }
}
