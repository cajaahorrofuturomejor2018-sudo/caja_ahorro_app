import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/services/ocr_service.dart';

/// Widget reutilizable para seleccionar una imagen (cámara/galería), mostrar
/// previsualización y procesarla con OCR. Devuelve el resultado mediante el
/// callback `onProcessed` con un Map {'texto','monto','fecha'} y el File.
class VoucherPicker extends StatefulWidget {
  final void Function(Map<String, dynamic> result, File file) onProcessed;
  final bool autoProcess;

  const VoucherPicker({
    super.key,
    required this.onProcessed,
    this.autoProcess = false,
  });

  @override
  State<VoucherPicker> createState() => _VoucherPickerState();
}

class _VoucherPickerState extends State<VoucherPicker> {
  File? _file;
  bool _processing = false;
  final ImagePicker _picker = ImagePicker();
  final OCRService _ocr = OCRService();

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => _file = file);
    if (widget.autoProcess) {
      await _process(file);
    }
  }

  Future<void> _process(File file) async {
    setState(() => _processing = true);
    try {
      final data = await _ocr.extractVoucherData(file);
      widget.onProcessed(data, file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error OCR: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_file != null)
          Center(child: Image.file(_file!, height: 160))
        else
          Container(
            height: 160,
            color: Colors.grey[200],
            child: const Center(
              child: Text('Selecciona una imagen de váucher'),
            ),
          ),
        const SizedBox(height: 10),
        // Use a Wrap instead of Row so buttons can wrap on small screens
        // and avoid RenderFlex overflow when the keyboard is open or on
        // narrow devices.
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            ElevatedButton.icon(
              onPressed: _processing ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Cámara'),
            ),
            ElevatedButton.icon(
              onPressed: _processing ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo),
              label: const Text('Galería'),
            ),
            ElevatedButton.icon(
              onPressed: (_file == null || _processing)
                  ? null
                  : () => _process(_file!),
              icon: const Icon(Icons.scanner),
              label: _processing
                  ? const Text('Procesando...')
                  : const Text('Procesar (OCR)'),
            ),
          ],
        ),
      ],
    );
  }
}
