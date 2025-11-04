import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:caja_ahorro_app/core/services/firestore_service.dart';
import 'package:caja_ahorro_app/models/deposito.dart';
import 'package:caja_ahorro_app/models/usuario.dart';
import 'package:caja_ahorro_app/widgets/voucher_picker.dart';

class _MemberEntry {
  String? selectedUid;
  final TextEditingController montoCtrl = TextEditingController();
  String tipo;

  _MemberEntry() : tipo = 'ahorro';

  void dispose() {
    montoCtrl.dispose();
  }
}

class DepositoForm extends StatefulWidget {
  const DepositoForm({super.key});

  @override
  State<DepositoForm> createState() => _DepositoFormState();
}

class _DepositoFormState extends State<DepositoForm> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _manualAccountDigitsCtrl = TextEditingController();
  final _montoTotalCtrl = TextEditingController();

  // Miembros: mantengo una pequeña clase manejadora para controllers por fila
  final List<_MemberEntry> _members = [];
  final FirestoreService _service = FirestoreService();
  List<Usuario> _currentFamilyUsuarios = [];
  String? _selectedFamiliaId;

  File? _pickedFile;
  Map<String, dynamic>? _ocrResult;
  bool _processing = false;
  // El selector global de tipo fue removido. El tipo se tomará de los miembros
  // (si existen) o por defecto será 'ahorro' al guardar.

  @override
  void dispose() {
    _montoCtrl.dispose();
    _descripcionCtrl.dispose();
    _manualAccountDigitsCtrl.dispose();
    _montoTotalCtrl.dispose();
    for (final m in _members) {
      m.dispose();
    }
    super.dispose();
  }

  String? _manualDigitsValidator(String? v) {
    final detected = _ocrResult != null
        ? (_ocrResult!['detected_account_digits'] as String?)
        : null;
    final accountMatches = _ocrResult != null
        ? (_ocrResult!['account_matches'] as bool?)
        : null;
    // If OCR detected and matches the user's stored account, manual input is optional
    if (detected != null && detected.isNotEmpty && accountMatches == true) {
      return null;
    }

    if (v == null || v.trim().isEmpty) {
      return 'Se requiere indicar los últimos dígitos de la cuenta destino';
    }
    final candidate = v.trim();
    // Enforce exactly 3 or 4 digits
    final match = RegExp(r'^\d{3,4}$').firstMatch(candidate);
    if (match == null) {
      return 'Ingrese 3 o 4 dígitos válidos';
    }
    return null;
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    // Require at least one miembro (familia) — for this app deposits should be family-type
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Agregue al menos un miembro de la familia al depósito.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    // Validación adicional: si hay miembros, la suma de sus montos debe
    // coincidir exactamente con el monto total (en centavos) para evitar
    // inserciones incorrectas.
    final montoTotal =
        double.tryParse(_montoTotalCtrl.text.replaceAll(',', '.')) ??
        double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ??
        0.0;
    if (_members.isNotEmpty) {
      final totalCents = (montoTotal * 100).round();
      var sumCents = 0;
      for (final m in _members) {
        final mm =
            double.tryParse(m.montoCtrl.text.replaceAll(',', '.')) ?? 0.0;
        sumCents += (mm * 100).round();
      }
      if (sumCents != totalCents) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La suma de montos por miembro debe coincidir con el monto total.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    setState(() => _processing = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    String archivoUrl = '';
    try {
      if (_pickedFile != null) {
        final isPdf = _pickedFile!.path.toLowerCase().endsWith('.pdf');
        final ext = isPdf ? 'pdf' : 'jpg';
        final ref = FirebaseStorage.instance.ref().child(
          'depositos/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext',
        );
        await ref.putFile(_pickedFile!);
        archivoUrl = await ref.getDownloadURL();
      }

      final montoTotal =
          double.tryParse(_montoTotalCtrl.text.replaceAll(',', '.')) ??
          double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ??
          0.0;

      // Prefer OCR verified digits, otherwise the manual input
      String? detectedDigits;
      if (_ocrResult != null && (_ocrResult!['account_matches'] == true)) {
        detectedDigits = _ocrResult!['detected_account_digits'] as String?;
      } else if (_manualAccountDigitsCtrl.text.trim().isNotEmpty) {
        detectedDigits = _manualAccountDigitsCtrl.text.trim();
      }

      // Construir detalle_por_usuario si hay miembros
      List<Map<String, dynamic>>? detalle;
      if (_members.isNotEmpty) {
        detalle = _members.map((m) {
          return {
            'id_usuario': m.selectedUid ?? '',
            'tipo': m.tipo,
            'monto':
                double.tryParse(m.montoCtrl.text.replaceAll(',', '.')) ?? 0.0,
          };
        }).toList();
      }

      // Generar voucherHash dando prioridad a un número de Comprobante/Documento
      // extraído por el OCR o detectado en el texto. Si existe, usar su hash
      // (esto garantiza que el mismo comprobante no pueda subirse dos veces).
      String? voucherHash;
      try {
        String? comprobanteRaw;
        if (_ocrResult != null) {
          // Intentar claves comunes en el resultado OCR
          final keys = [
            'comprobante',
            'documento',
            'comprobante_num',
            'nro_comprobante',
            'numero_comprobante',
            'comprobante_nro',
            'documento_nro',
          ];
          for (final k in keys) {
            final v = _ocrResult![k];
            if (v is String && v.trim().isNotEmpty) {
              comprobanteRaw = v.trim();
              break;
            } else if (v != null) {
              final s = v.toString().trim();
              if (s.isNotEmpty) {
                comprobanteRaw = s;
                break;
              }
            }
          }

          // Si no se encontró por clave, intentar extraer del texto OCR con regex
          if (comprobanteRaw == null) {
            final texto =
                (_ocrResult!['texto'] ?? _ocrResult!['ocr_text']) as String?;
            if (texto != null && texto.isNotEmpty) {
              // Use case-insensitive RegExp via constructor flag; avoid inline (?i)
              final patterns = <RegExp>[
                RegExp(
                  r'comprobante[^\d]*(\d[\d\-/\\]*)',
                  caseSensitive: false,
                ),
                RegExp(r'documento[^\d]*(\d[\d\-/\\]*)', caseSensitive: false),
                RegExp(
                  r'n[oº]\.?\s*[:#-]?\s*(\d[\d\-/\\]*)',
                  caseSensitive: false,
                ),
                RegExp(
                  r'nro\.?\s*[:#-]?\s*(\d[\d\-/\\]*)',
                  caseSensitive: false,
                ),
                RegExp(r'no\.\s*(\d[\d\-/\\]*)', caseSensitive: false),
              ];
              for (final p in patterns) {
                final m = p.firstMatch(texto);
                if (m != null && m.groupCount >= 1) {
                  final candidate = m.group(1);
                  if (candidate != null && candidate.trim().isNotEmpty) {
                    comprobanteRaw = candidate.trim();
                    break;
                  }
                }
              }
            }
          }
        }

        // Si encontramos comprobante, usarlo (normalizado) para generar hash
        if (comprobanteRaw != null && comprobanteRaw.isNotEmpty) {
          final normalized = comprobanteRaw
              .replaceAll(RegExp(r'\s+'), '')
              .replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
          final seed = utf8.encode('$normalized|$uid');
          voucherHash = sha256.convert(seed).toString();
        } else {
          // Fallback al comportamiento anterior: si hay archivo usar bytes,
          // si no usar uid+timestamp
          if (_pickedFile != null) {
            final bytes = await _pickedFile!.readAsBytes();
            final seed =
                bytes +
                utf8.encode(uid) +
                utf8.encode(DateTime.now().toIso8601String());
            voucherHash = sha256.convert(seed).toString();
          } else {
            final seed = utf8.encode(
              '$uid|${DateTime.now().millisecondsSinceEpoch}',
            );
            voucherHash = sha256.convert(seed).toString();
          }
        }
      } catch (_) {
        voucherHash = null;
      }

      // Determinar el tipo del depósito:
      // - si no hay miembros -> 'ahorro' por defecto
      // - si todos los miembros tienen el mismo tipo -> ese tipo
      // - si hay tipos mezclados -> 'mixto'
      final String tipoDep;
      if (_members.isEmpty) {
        tipoDep = 'ahorro';
      } else {
        final tipos = _members.map((m) => m.tipo).toSet();
        tipoDep = tipos.length == 1 ? tipos.first : 'mixto';
      }

      final dep = Deposito(
        // idUsuario aquí se usa como autor/solicitante del depósito (quien sube el comprobante)
        idUsuario: uid,
        tipo: tipoDep,
        monto: montoTotal,
        voucherHash: voucherHash,
        fechaDeposito: DateTime.now(),
        archivoUrl: archivoUrl,
        descripcion: _descripcionCtrl.text.isNotEmpty
            ? _descripcionCtrl.text
            : null,
        detallePorUsuario: detalle,
        ocrText: _ocrResult != null ? (_ocrResult!['texto'] as String?) : null,
        detectedAccountRaw: _ocrResult != null
            ? (_ocrResult!['detected_account_raw'] as String?)
            : null,
        detectedAccountDigits: detectedDigits,
        detectedName: _ocrResult != null
            ? (_ocrResult!['detected_name'] as String?)
            : null,
        fechaDetectada: _ocrResult != null
            ? (_ocrResult!['parsed']?['fecha'] as String?)
            : null,
        voucherIsPdf:
            _pickedFile != null &&
            _pickedFile!.path.toLowerCase().endsWith('.pdf'),
        ocrVerified:
            (_ocrResult != null && (_ocrResult!['account_matches'] == true)),
      );

      final service = FirestoreService();
      await service.addDeposito(dep);
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error al guardar: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detected = _ocrResult != null
        ? (_ocrResult!['detected_account_digits'] as String?)
        : null;
    final accountMatches = _ocrResult != null
        ? (_ocrResult!['account_matches'] as bool?)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar depósito')),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // El selector global de tipo fue eliminado. El tipo por defecto
                // se aplicará en la construcción del depósito si no hay miembros.
                VoucherPicker(
                  onProcessed: (result, file) {
                    final monto = (result['monto'] is double)
                        ? result['monto'] as double
                        : double.tryParse(result['monto'].toString()) ?? 0.0;
                    setState(() {
                      _pickedFile = file;
                      _ocrResult = result;
                      final last4 = result['detected_account_last4'] as String?;
                      final last3 = result['detected_account_last3'] as String?;
                      if (last4 != null && last4.isNotEmpty) {
                        _manualAccountDigitsCtrl.text = last4;
                      } else if (last3 != null && last3.isNotEmpty) {
                        _manualAccountDigitsCtrl.text = last3;
                      }
                      _montoCtrl.text = monto > 0
                          ? monto.toStringAsFixed(2)
                          : '';
                      _montoTotalCtrl.text = monto > 0
                          ? monto.toStringAsFixed(2)
                          : '';
                    });
                  },
                ),

                const SizedBox(height: 12),

                if (detected != null && detected.isNotEmpty) ...[
                  Text(
                    'Cuenta detectada (parcial): ${detected.length >= 4 ? detected.substring(detected.length - 4) : detected}',
                  ),
                  if (accountMatches == true)
                    const Text(
                      'La cuenta coincide con la registrada ✅',
                      style: TextStyle(color: Colors.green),
                    ),
                  if (accountMatches == false)
                    const Text(
                      'La cuenta NO coincide con la registrada ❌',
                      style: TextStyle(color: Colors.red),
                    ),
                ] else ...[
                  const Text(
                    'No se detectó cuenta destino en el comprobante.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ],

                const SizedBox(height: 8),

                TextFormField(
                  controller: _manualAccountDigitsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText:
                        'Últimos 3-4 dígitos de la cuenta destino (requerido si OCR no detecta o no coincide)',
                    helperText: 'Ingrese solo dígitos, ejemplo: 5678 o 678',
                  ),
                  validator: _manualDigitsValidator,
                ),

                const SizedBox(height: 12),

                // Monto total del voucher
                TextFormField(
                  controller: _montoTotalCtrl,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monto total (comprobante)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Ingrese el monto total' : null,
                ),

                const SizedBox(height: 12),

                // Seleccionar familia (obligatorio para depósitos familiares)
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _service.streamFamilias(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    final familias = snap.data!;
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedFamiliaId,
                      decoration: const InputDecoration(
                        labelText: 'Grupo familiar (seleccione)',
                      ),
                      items: familias
                          .map(
                            (f) => DropdownMenuItem(
                              value: f['id'] as String?,
                              child: Text(f['nombre_grupo'] ?? 'Grupo'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) async {
                        setState(() {
                          _selectedFamiliaId = v;
                          _currentFamilyUsuarios = [];
                        });
                        if (v != null && v.isNotEmpty) {
                          try {
                            final fam = await _service.getFamiliaById(v);
                            if (fam != null) {
                              final miembros =
                                  (fam['miembros'] as List<dynamic>?)
                                      ?.map(
                                        (e) => (e is Map)
                                            ? (e['id_usuario'] ?? '')
                                            : e,
                                      )
                                      .whereType<String>()
                                      .toList() ??
                                  [];
                              if (miembros.isNotEmpty) {
                                final users = await _service.getUsuariosByIds(
                                  miembros,
                                );
                                if (mounted) {
                                  setState(
                                    () => _currentFamilyUsuarios = users,
                                  );
                                }
                              }
                            }
                          } catch (_) {}
                        }
                      },
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Sección de miembros (obligatorio para depósitos familiares)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Miembros (familia - obligatorio):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _members.add(_MemberEntry())),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _members.length; i++)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _members[i].selectedUid,
                                  decoration: const InputDecoration(
                                    labelText: 'Miembro (seleccionar)',
                                  ),
                                  items: _currentFamilyUsuarios
                                      .map(
                                        (u) => DropdownMenuItem(
                                          value: u.id,
                                          child: Text(u.nombres),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(() {
                                    _members[i].selectedUid = v;
                                  }),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Seleccione miembro'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _members[i].tipo,
                                  isExpanded: true,
                                  isDense: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'ahorro',
                                      child: Text('Ahorro'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'pago_prestamo',
                                      child: Text('Pago préstamo'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'plazo_fijo',
                                      child: Text('Plazo fijo'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'certificado',
                                      child: Text('Certificado'),
                                    ),
                                  ],
                                  onChanged: (v) => setState(
                                    () => _members[i].tipo = v ?? 'ahorro',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  iconSize: 20,
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => setState(() {
                                    _members[i].dispose();
                                    _members.removeAt(i);
                                  }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _members[i].montoCtrl,
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Monto miembro',
                                  ),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Ingrese monto'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                  ),
                ),

                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: _processing ? null : _onSave,
                    child: _processing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar depósito'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
