import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

class MlService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Descarga una imagen desde `url` y ejecuta OCR, devolviendo el texto detectado.
  Future<String> analyzeImageFromUrl(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('No se pudo descargar la imagen');
    }
    final bytes = res.bodyBytes;
    final temp = File(
      '${Directory.systemTemp.path}/voucher_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await temp.writeAsBytes(bytes);
    final inputImage = InputImage.fromFilePath(temp.path);
    final result = await _recognizer.processImage(inputImage);
    // Combinar líneas de texto detectadas
    final text = result.blocks.map((b) => b.text).join('\n');
    // limpiar el archivo temporal
    try {
      await temp.delete();
    } catch (_) {}
    return text;
  }

  /// Extrae campos heurísticos (monto, fecha, número de cuenta enmascarado) desde el texto OCR.
  Map<String, String?> extractFields(String ocrText) {
    String? monto;
    String? fecha;
    String? cuenta;

    // Heurísticas simples: buscar números con formato de moneda
    final moneyRe = RegExp(r"\b\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})\b");
    final dateRe = RegExp(r"\b(\d{2}[\-/]\d{2}[\-/]\d{2,4})\b");
    final acctRe = RegExp(r"\b\d{3,}.*\d{3}\b");

    final m = moneyRe.firstMatch(ocrText);
    if (m != null) {
      monto = m.group(0);
    }
    final d = dateRe.firstMatch(ocrText);
    if (d != null) {
      fecha = d.group(0);
    }
    final a = acctRe.firstMatch(ocrText);
    if (a != null) {
      cuenta = a.group(0);
    }

    // Enmascarar cuenta si es larga
    if (cuenta != null && cuenta.length > 6) {
      final start = cuenta.substring(0, 3);
      final end = cuenta.substring(cuenta.length - 3);
      cuenta = '$start***$end';
    }

    return {'monto': monto, 'fecha': fecha, 'cuenta': cuenta};
  }

  void dispose() {
    _recognizer.close();
  }
}
