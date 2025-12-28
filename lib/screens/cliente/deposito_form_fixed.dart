import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:caja_ahorro_app/core/services/firestore_service.dart';
import 'package:caja_ahorro_app/models/deposito.dart';
import 'package:caja_ahorro_app/widgets/voucher_picker.dart';

class DepositoForm extends StatefulWidget {
  const DepositoForm({super.key});

  @override
  State<DepositoForm> createState() => _DepositoFormState();
}

class _DepositoFormState extends State<DepositoForm> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _montoTotalCtrl = TextEditingController();

  final FirestoreService _service = FirestoreService();
  String _selectedTipo = 'ahorro';
  bool _hasMultas = false;
  bool _esDepuesDiaDiez = false;

  @override
  void initState() {
    super.initState();
    _loadUserFlags();
    _checkFecha();
  }

  void _checkFecha() {
    final ahora = DateTime.now();
    setState(() {
      _esDepuesDiaDiez = ahora.day > 10;
    });
  }

  Future<void> _loadUserFlags() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final u = await _service.getUsuario(uid);
      if (!mounted) return;
      setState(() {
        _hasMultas = (u?.totalMultas ?? 0) > 0.0;
      });
    } catch (_) {}
  }

  File? _pickedFile;
  Map<String, dynamic>? _ocrResult;
  bool _processing = false;
  // El selector global de tipo fue removido. El tipo se tomará de los miembros
  // (si existen) o por defecto será 'ahorro' al guardar.

  @override
  void dispose() {
    _montoCtrl.dispose();
    _descripcionCtrl.dispose();
    _montoTotalCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    // IMPORTANTE: Removida la validación que bloqueaba depósitos cuando hay multas.
    // El usuario puede hacer depósitos normales (ahorro, pago_prestamo, ahorro_voluntario)
    // incluso si tiene multas pendientes. Las multas se pagan en el formulario específico.
    // Esta lógica previa causaba bloqueos incorrectos y afectaba la experiencia del usuario.

    // Deposito personal: no hay reparto por familia. El depósito se asigna
    // directamente al usuario que lo registra (current user).
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

      // Prefer OCR detected digits (optional, no input manual)
      String? detectedDigits;
      if (_ocrResult != null) {
        detectedDigits =
            (_ocrResult!['detected_account_digits'] as String?) ??
            (_ocrResult!['detected_account_last4'] as String?) ??
            (_ocrResult!['detected_account_last3'] as String?);
      }

      // Deposito personal: no detalle_por_usuario
      List<Map<String, dynamic>>? detalle;

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

      // Determinar el tipo del depósito según selector del formulario
      final String tipoDep = _selectedTipo;

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
                    'Ingrese el monto Total',
                    style: TextStyle(color: Colors.orange),
                  ),
                ],

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

                // Mensaje de advertencia si hay multas y es después del día 10
                if (_hasMultas && _esDepuesDiaDiez) ...[
                  Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: const [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tiene multas pendientes. Debe pagarlas desde el apartado de multas. Los tipos "Ahorro mensual" y "Pago préstamo" están desactivados.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                const SizedBox(height: 12),
                // Selector de tipo de depósito (depósito personal)
                DropdownButtonFormField<String>(
                  initialValue: _selectedTipo,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de depósito',
                    border: OutlineInputBorder(),
                    helperText: 'Seleccione el tipo de depósito a realizar',
                  ),
                  items: [
                    // Ahorro mensual y Pago préstamo desactivados si hay multas después del día 10
                    DropdownMenuItem(
                      value: 'ahorro',
                      enabled: !(_hasMultas && _esDepuesDiaDiez),
                      child: Row(
                        children: [
                          Text(
                            'Ahorro (mensual)',
                            style: TextStyle(
                              color: (_hasMultas && _esDepuesDiaDiez)
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                          ),
                          if (_hasMultas && _esDepuesDiaDiez)
                            const SizedBox(width: 8),
                          if (_hasMultas && _esDepuesDiaDiez)
                            const Icon(
                              Icons.block,
                              size: 16,
                              color: Colors.red,
                            ),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'pago_prestamo',
                      enabled: !(_hasMultas && _esDepuesDiaDiez),
                      child: Row(
                        children: [
                          Text(
                            'Pago préstamo',
                            style: TextStyle(
                              color: (_hasMultas && _esDepuesDiaDiez)
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                          ),
                          if (_hasMultas && _esDepuesDiaDiez)
                            const SizedBox(width: 8),
                          if (_hasMultas && _esDepuesDiaDiez)
                            const Icon(
                              Icons.block,
                              size: 16,
                              color: Colors.red,
                            ),
                        ],
                      ),
                    ),
                    const DropdownMenuItem(
                      value: 'plazo_fijo',
                      child: Text('Plazo fijo'),
                    ),
                    const DropdownMenuItem(
                      value: 'certificado',
                      child: Text('Certificado de aportación'),
                    ),
                    const DropdownMenuItem(
                      value: 'ahorro_voluntario',
                      child: Text('Ahorro voluntario'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedTipo = v ?? 'ahorro'),
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

// Si usas Firebase Auth en el front:
// (await import('firebase/auth')).getAuth().currentUser.getIdToken(true).then(console.log)
