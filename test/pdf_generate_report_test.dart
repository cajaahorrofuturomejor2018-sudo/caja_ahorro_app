import 'package:flutter_test/flutter_test.dart';
import 'package:caja_ahorro_app/core/services/pdf_service.dart';

void main() {
  test(
    'PDFService.generateReportPdf devuelve bytes no vacíos para mapa simple',
    () async {
      final pdfService = PDFService();
      final data = {
        'generated_at': DateTime.now().toIso8601String(),
        'total_depositos': 1234.56,
        'total_prestamos': 789.0,
        'detalle': {'ejemplo': 'valor'},
      };

      final bytes = await pdfService.generateReportPdf(data);
      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(0));
    },
  );
}
