import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

/// compartir o guardar en documentos.
class PdfPreviewScreen extends StatelessWidget {
  final Uint8List bytes;
  final String filename;

  const PdfPreviewScreen({
    super.key,
    required this.bytes,
    this.filename = 'reporte.pdf',
  });

  Future<String> _saveToDocuments() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> _share(BuildContext context) async {
    try {
      // Share PDF bytes directly using printing package
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista previa del PDF'),
        actions: [
          IconButton(
            tooltip: 'Imprimir',
            icon: const Icon(Icons.print),
            onPressed: () => Printing.layoutPdf(onLayout: (_) => bytes),
          ),
          IconButton(
            tooltip: 'Compartir',
            icon: const Icon(Icons.share),
            onPressed: () => _share(context),
          ),
          IconButton(
            tooltip: 'Guardar',
            icon: const Icon(Icons.save_alt),
            onPressed: () async {
              final path = await _saveToDocuments();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Guardado en: $path')));
              }
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) async => bytes,
        allowSharing: false, // handled by our own share button
        allowPrinting: true,
        canChangePageFormat: true,
      ),
    );
  }
}
