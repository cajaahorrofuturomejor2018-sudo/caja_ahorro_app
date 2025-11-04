import 'package:flutter_test/flutter_test.dart';
import 'package:caja_ahorro_app/core/services/ocr_service.dart';

void main() {
  test('parseText extrae monto y fecha correctamente', () {
    final texto = 'Pago recibido\nFecha: 12/08/2024\nTotal: 1.234,56\nGracias';
    final result = OCRService.parseText(texto);
    expect(result['texto'], contains('Pago recibido'));
    expect(result['monto'], greaterThan(0));
    expect(result['fecha'], equals('12/08/2024'));
  });

  test('parseText maneja formatos simples', () {
    final texto = 'Monto: 250.00\nFecha 1/1/25';
    final result = OCRService.parseText(texto);
    expect(result['monto'], greaterThan(0));
    expect(result['fecha'], contains('1/1'));
  });
}
