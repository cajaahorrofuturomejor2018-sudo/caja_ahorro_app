import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/ocr_service.dart';
import '../../core/services/firestore_service.dart';
import '../../models/deposito.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:crypto/crypto.dart';

class UploadVoucher extends StatefulWidget {
  const UploadVoucher({super.key});

  @override
  State<UploadVoucher> createState() => _UploadVoucherState();
}

class _UploadVoucherState extends State<UploadVoucher> {
  File? _image;
  bool _processing = false;
  String _textoExtraido = '';
  double _montoDetectado = 0;
  String _fechaDetectada = '';
  String? _detectedName;
  String? _detectedAccountRaw;
  String? _detectedAccountDigits;
  bool? _accountMatches;
  List<Map<String, dynamic>> _candidates = [];
  int? _selectedCandidateIndex;
  final TextEditingController _montoController = TextEditingController();

  final picker = ImagePicker();
  final storage = StorageService();
  final ocr = OCRService();
  final firestore = FirestoreService();

  Future<void> _pickPdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (res != null && res.files.isNotEmpty && res.files.single.path != null) {
      setState(() => _image = File(res.files.single.path!));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<void> _procesarImagen() async {
    if (_image == null) return;
    setState(() => _processing = true);

    // Intentar obtener la cuenta registrada del usuario para verificación parcial
    String? registeredAccount;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final usuario = await firestore.getUsuario(uid);
        registeredAccount = usuario?.numeroCuenta;
      }
    } catch (_) {}

    final data = await ocr.extractVoucherData(
      _image!,
      registeredAccount: registeredAccount,
    );

    setState(() {
      _textoExtraido = data['texto'] ?? '';
      _montoDetectado = (data['monto'] is num)
          ? (data['monto'] as num).toDouble()
          : 0.0;
      _fechaDetectada = data['fecha'] ?? '';
      _detectedName = data['detected_name'];
      _detectedAccountRaw = data['detected_account_raw'];
      _detectedAccountDigits = data['detected_account_digits'];
      _accountMatches = data['account_matches'];

      // Load candidates if present (each candidate: {amount: double, line: String, hasKeyword: bool})
      _candidates = [];
      if (data['candidates'] is List) {
        try {
          _candidates = List<Map<String, dynamic>>.from(data['candidates']);
        } catch (_) {
          _candidates = [];
        }
      }

      // Try to set preferred candidate
      _selectedCandidateIndex = null;
      if (data['preferred'] != null) {
        try {
          final pref = Map<String, dynamic>.from(data['preferred']);
          final idx = _candidates.indexWhere(
            (c) => c['line'] == pref['line'] && c['amount'] == pref['amount'],
          );
          if (idx >= 0) _selectedCandidateIndex = idx;
        } catch (_) {}
      }

      if (_selectedCandidateIndex == null && _candidates.isNotEmpty) {
        _selectedCandidateIndex = 0;
      }

      final initialMonto = _selectedCandidateIndex != null
          ? ((_candidates[_selectedCandidateIndex!]['amount'] is num)
                ? (_candidates[_selectedCandidateIndex!]['amount'] as num)
                      .toDouble()
                : 0.0)
          : _montoDetectado;
      _montoController.text = initialMonto > 0
          ? initialMonto.toStringAsFixed(2)
          : '';
    });

    setState(() => _processing = false);
  }

  Future<void> _guardarDeposito() async {
    if (_image == null) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    // Capture messenger and navigator before async work to avoid context-after-await issues
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    // Parse monto from editable field
    final parsedMonto =
        double.tryParse(_montoController.text.replaceAll(',', '.')) ?? 0.0;
    if (parsedMonto <= 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor ingresa o selecciona un monto válido antes de guardar',
          ),
        ),
      );
      return;
    }

    setState(() => _processing = true);
    // compute voucher hash using file bytes + ocr text + monto + detected date
    String? voucherHash;
    try {
      final bytes = await _image!.readAsBytes();
      // simple hash: sha256(bytes + ocrText + monto + fechaDetectada)
      final combined = <int>[];
      combined.addAll(bytes);
      combined.addAll(utf8.encode(_textoExtraido));
      combined.addAll(utf8.encode(parsedMonto.toString()));
      combined.addAll(utf8.encode(_fechaDetectada));
      voucherHash = sha256.convert(combined).toString();
    } catch (_) {
      voucherHash = null;
    }

    final url = await storage.uploadFile(_image!, 'vauchers');

    final dep = Deposito(
      idUsuario: uid,
      tipo: 'ahorro',
      monto: parsedMonto,
      voucherHash: voucherHash,
      fechaDeposito: DateTime.now(),
      archivoUrl: url,
      validado: false,
      descripcion: _textoExtraido.isNotEmpty ? _textoExtraido : null,
      detallePorUsuario: null,
      ocrText: _textoExtraido.isNotEmpty ? _textoExtraido : null,
      detectedAccountRaw: _detectedAccountRaw,
      detectedAccountDigits: _detectedAccountDigits,
      detectedName: _detectedName,
      fechaDetectada: _fechaDetectada.isNotEmpty ? _fechaDetectada : null,
    );

    // Validaciones estrictas antes de guardar: debe detectarse una cuenta destino
    if (_detectedAccountDigits == null || _detectedAccountDigits!.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No se detectó una cuenta destino en el comprobante. Por seguridad, la aplicación requiere que la cuenta destino esté presente (últimos 3-4 dígitos). Verifica el comprobante o utiliza el formulario manual para especificarla.',
          ),
        ),
      );
      setState(() => _processing = false);
      return;
    }

    // Si tenemos verificación contra la cuenta registrada y no coincide, bloquear
    if (_accountMatches == false) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'La cuenta detectada NO coincide con la cuenta registrada en su perfil. Corregir o contactar soporte. El depósito no será registrado.',
          ),
        ),
      );
      setState(() => _processing = false);
      return;
    }

    await firestore.addDeposito(dep);

    if (mounted) {
      setState(() => _processing = false);
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Depósito registrado correctamente')),
    );
    navigator.pop();
  }

  @override
  void dispose() {
    ocr.dispose();
    _montoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subir váucher')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_image != null)
              (_image!.path.toLowerCase().endsWith('.pdf')
                  ? Container(
                      height: 140,
                      color: Colors.grey[100],
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              size: 48,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _image!.path.split(Platform.pathSeparator).last,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'PDF seleccionado. Si desea extraer texto debe habilitar extracción de PDF en la configuración.',
                            ),
                          ],
                        ),
                      ),
                    )
                  : Image.file(_image!, height: 250, fit: BoxFit.cover))
            else
              Container(
                height: 250,
                color: Colors.grey[200],
                child: const Center(child: Text('Selecciona una imagen')),
              ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Cámara'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.image),
                  label: const Text('Galería'),
                ),
                ElevatedButton.icon(
                  onPressed: _pickPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Subir PDF'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_image != null)
              ElevatedButton(
                onPressed: _procesarImagen,
                child: const Text('Procesar imagen (OCR)'),
              ),
            const SizedBox(height: 15),
            if (_processing)
              const CircularProgressIndicator()
            else if (_textoExtraido.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fecha detectada: $_fechaDetectada',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      if (_detectedName != null || _detectedAccountRaw != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_detectedName != null)
                              Text(
                                'Nombre detectado: ${_detectedName!}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (_detectedAccountRaw != null) ...[
                              const SizedBox(height: 4),
                              Text('Cuenta detectada: ${_detectedAccountRaw!}'),
                              if (_detectedAccountDigits != null)
                                Text(
                                  'Últimos dígitos: ${_detectedAccountDigits!.length >= 4 ? _detectedAccountDigits!.substring(_detectedAccountDigits!.length - 4) : (_detectedAccountDigits!.length >= 3 ? _detectedAccountDigits!.substring(_detectedAccountDigits!.length - 3) : _detectedAccountDigits)}',
                                ),
                              const SizedBox(height: 4),
                              if (_accountMatches == true)
                                const Text(
                                  'La cuenta coincide con la registrada ✅',
                                  style: TextStyle(color: Colors.green),
                                )
                              else if (_accountMatches == false)
                                const Text(
                                  'La cuenta NO coincide con la registrada ❌',
                                  style: TextStyle(color: Colors.red),
                                )
                              else
                                const SizedBox.shrink(),
                            ],
                            const SizedBox(height: 8),
                          ],
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Texto extraído:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _textoExtraido,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Divider(),

                      const Text(
                        'Candidatos de monto encontrados:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      if (_candidates.isEmpty)
                        const Text(
                          'No se encontraron candidatos automáticos. Por favor ingresa el monto manualmente.',
                        ),
                      for (var i = 0; i < _candidates.length; i++)
                        RadioListTile<int>(
                          value: i,
                          groupValue: _selectedCandidateIndex,
                          title: Text(
                            '\$${(_candidates[i]['amount'] is num ? (_candidates[i]['amount'] as num).toDouble() : 0.0).toStringAsFixed(2)}',
                          ),
                          subtitle: Text(_candidates[i]['line'] ?? ''),
                          onChanged: (v) {
                            setState(() {
                              _selectedCandidateIndex = v;
                              final amt = (_candidates[v!]['amount'] is num)
                                  ? (_candidates[v]['amount'] as num).toDouble()
                                  : 0.0;
                              _montoController.text = amt > 0
                                  ? amt.toStringAsFixed(2)
                                  : '';
                            });
                          },
                        ),

                      const SizedBox(height: 8),
                      const Text(
                        'Monto (editar si es necesario):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _montoController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          prefixText: '\$',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 15),
                      Center(
                        child: ElevatedButton(
                          onPressed: _guardarDeposito,
                          child: const Text('Guardar depósito'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
