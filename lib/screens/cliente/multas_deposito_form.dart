import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:caja_ahorro_app/core/services/firestore_service.dart';
import 'package:caja_ahorro_app/models/deposito.dart';
import 'package:caja_ahorro_app/widgets/voucher_picker.dart';

/// Formulario específico para pago de MULTAS
/// Solo se muestra después del día 10 cuando el usuario tiene multas pendientes
/// El valor de la multa se divide: una parte va a la caja y otra al usuario
class MultasDepositoForm extends StatefulWidget {
  const MultasDepositoForm({super.key});

  @override
  State<MultasDepositoForm> createState() => _MultasDepositoFormState();
}

class _MultasDepositoFormState extends State<MultasDepositoForm> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _montoTotalCtrl = TextEditingController();
  bool _processing = false;

  File? _pickedFile;
  Map<String, dynamic>? _ocrResult;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _descripcionCtrl.dispose();
    _montoTotalCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

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
          'multas/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext',
        );
        await ref.putFile(_pickedFile!);
        archivoUrl = await ref.getDownloadURL();
      }

      final montoTotal =
          double.tryParse(_montoTotalCtrl.text.replaceAll(',', '.')) ??
          double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ??
          0.0;

      String? detectedDigits;
      if (_ocrResult != null) {
        detectedDigits =
            (_ocrResult!['detected_account_digits'] as String?) ??
            (_ocrResult!['detected_account_last4'] as String?) ??
            (_ocrResult!['detected_account_last3'] as String?);
      }

      // Generar voucherHash para evitar duplicados
      String? voucherHash;
      try {
        String? comprobanteRaw;
        if (_ocrResult != null) {
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

          if (comprobanteRaw == null) {
            final texto =
                (_ocrResult!['texto'] ?? _ocrResult!['ocr_text']) as String?;
            if (texto != null && texto.isNotEmpty) {
              final patterns = <RegExp>[
                RegExp(
                  r'comprobante[^\d]*(\d[\d\-/\\]*)',
                  caseSensitive: false,
                ),
                RegExp(r'documento[^\d]*(\d[\d\-/\\]*)', caseSensitive: false),
                RegExp(r'n[úuoó]m[\.\s]*(\d[\d\-/\\]*)', caseSensitive: false),
              ];
              for (final rx in patterns) {
                final m = rx.firstMatch(texto);
                if (m != null && m.groupCount > 0) {
                  final c = m.group(1) ?? '';
                  if (c.isNotEmpty) {
                    comprobanteRaw = c;
                    break;
                  }
                }
              }
            }
          }
        }

        if (comprobanteRaw != null && comprobanteRaw.isNotEmpty) {
          final normalized = comprobanteRaw
              .replaceAll(RegExp(r'[\s\-/\\]+'), '')
              .toUpperCase();
          final toHash = 'comprobante:$normalized';
          final digest = sha256.convert(utf8.encode(toHash));
          voucherHash = digest.toString();
        }
      } catch (_) {}

      // IMPORTANTE: Para multas, el depósito va con tipo 'multa'
      // El backend se encargará de dividir: parte para caja, parte para usuario
      final dep = Deposito(
        idUsuario: uid,
        tipo: 'multa', // Tipo específico para multas
        monto: montoTotal,
        voucherHash: voucherHash,
        fechaDeposito: DateTime.now(),
        archivoUrl: archivoUrl,
        descripcion: _descripcionCtrl.text.isNotEmpty
            ? _descripcionCtrl.text
            : 'Pago de multa',
        detallePorUsuario: null, // Multa individual, no hay reparto
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
        montoSobrante: 0.0,
        voucherIsPdf:
            _pickedFile != null &&
            _pickedFile!.path.toLowerCase().endsWith('.pdf'),
        ocrVerified:
            (_ocrResult != null && (_ocrResult!['account_matches'] == true)),
      );

      final service = FirestoreService();
      await service.addDeposito(dep);

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Pago de multa registrado. Pendiente de aprobación por admin.',
          ),
          backgroundColor: Colors.green,
        ),
      );
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
      appBar: AppBar(
        title: const Text('Pagar Multa'),
        backgroundColor: Colors.red[700],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Información sobre las multas
                Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Información sobre multas',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Esta multa se genera por:\n'
                          '• No realizar el ahorro mensual antes del día 10\n'
                          '• No cancelar la cuota del préstamo en la fecha acordada\n\n'
                          'El monto de la multa se divide entre:\n'
                          '• Una parte para la caja (ganancia)\n'
                          '• El resto se registra en tu cuenta',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

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
                    'No se detectó cuenta destino en el comprobante.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ],

                const SizedBox(height: 12),

                TextFormField(
                  controller: _montoTotalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monto total de la multa',
                    prefixIcon: Icon(Icons.attach_money),
                    helperText: 'Ingrese el monto total que va a pagar',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Ingrese el monto total' : null,
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                    ),
                    onPressed: _processing ? null : _onSave,
                    child: _processing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Registrar pago de multa',
                            style: TextStyle(fontSize: 16),
                          ),
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
