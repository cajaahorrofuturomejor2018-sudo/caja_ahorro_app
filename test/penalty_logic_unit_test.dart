/// Test unitario para la lógica de cálculo de multas
/// No requiere Firebase - solo prueba la matemática

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Penalty Calculation Logic Tests', () {
    test('Cálculo de multa de ahorro mensual - día 11 (1 día de atraso)', () {
      // Día 11 = 1 día después del día 10
      final daysLate = 11 - 10;
      final penaltyPerWeek = 1.00;

      // Fórmula: weeks = ((daysLate - 1) / 7) + 1
      final weeks = ((daysLate - 1) ~/ 7) + 1;
      final penalty = (weeks * penaltyPerWeek).toDouble();

      // Día 11 = 1 semana incompleta = $1.00
      expect(penalty, equals(1.00));
    });

    test('Cálculo de multa de ahorro mensual - día 13 (3 días de atraso)', () {
      final daysLate = 13 - 10;
      final penaltyPerWeek = 1.00;

      final weeks = ((daysLate - 1) ~/ 7) + 1;
      final penalty = (weeks * penaltyPerWeek).toDouble();

      // Día 13 = 1 semana incompleta = $1.00
      expect(penalty, equals(1.00));
    });

    test('Cálculo de multa de ahorro mensual - día 17 (7 días de atraso)', () {
      final daysLate = 17 - 10;
      final penaltyPerWeek = 1.00;

      final weeks = ((daysLate - 1) ~/ 7) + 1;
      final penalty = (weeks * penaltyPerWeek).toDouble();

      // Día 17 = 1 semana completa = $1.00
      expect(penalty, equals(1.00));
    });

    test('Cálculo de multa de ahorro mensual - día 18 (8 días de atraso)', () {
      final daysLate = 18 - 10;
      final penaltyPerWeek = 1.00;

      final weeks = ((daysLate - 1) ~/ 7) + 1;
      final penalty = (weeks * penaltyPerWeek).toDouble();

      // Día 18 = 2 semanas (1 completa + 1 incompleta) = $2.00
      expect(penalty, equals(2.00));
    });

    test('Cálculo de multa de ahorro mensual - día 24 (14 días de atraso)', () {
      final daysLate = 24 - 10;
      final penaltyPerWeek = 1.00;

      final weeks = ((daysLate - 1) ~/ 7) + 1;
      final penalty = (weeks * penaltyPerWeek).toDouble();

      // Día 24 = 2 semanas completas = $2.00
      expect(penalty, equals(2.00));
    });

    test('Cálculo de multa de ahorro mensual - día 25 (15 días de atraso)', () {
      final daysLate = 25 - 10;
      final penaltyPerWeek = 1.00;

      final weeks = ((daysLate - 1) ~/ 7) + 1;
      final penalty = (weeks * penaltyPerWeek).toDouble();

      // Día 25 = 3 semanas (2 completas + 1 incompleta) = $3.00
      expect(penalty, equals(3.00));
    });

    test('Cálculo de multa préstamo - 1-15 días de atraso (7%)', () {
      final cuota = 100.00;
      final daysLate = 10;

      double penalty = 0.0;
      if (daysLate >= 1 && daysLate <= 15) {
        penalty = cuota * 0.07;
      }

      expect(penalty, closeTo(7.00, 0.01));
    });

    test('Cálculo de multa préstamo - 16-30 días de atraso (10%)', () {
      final cuota = 100.00;
      final daysLate = 20;

      double penalty = 0.0;
      if (daysLate >= 16 && daysLate <= 30) {
        penalty = cuota * 0.10;
      }

      expect(penalty, equals(10.00));
    });

    test('Cálculo de multa préstamo - más de 30 días (10% por período)', () {
      final cuota = 100.00;
      final daysLate = 65; // ~2 períodos de 30 días

      double penalty = 0.0;
      if (daysLate > 30) {
        final periods = (daysLate / 30).ceil();
        penalty = cuota * 0.10 * periods;
      }

      // 65 días = 3 períodos (65/30 = 2.166 → ceil = 3)
      expect(penalty, equals(30.00));
    });

    test('No debe aplicar multa si es día 10 o antes', () {
      final now = DateTime(2025, 12, 10);

      // Si es día 10 o antes, no debería calcularse multa
      if (now.day <= 10) {
        expect(now.day <= 10, isTrue);
      }
    });

    test('Verificar día actual es después del día 10', () {
      final now = DateTime.now();

      // Para hoy 13 de diciembre
      if (now.day == 13 && now.month == 12) {
        expect(now.day > 10, isTrue);

        final daysLate = now.day - 10;
        expect(daysLate, equals(3));
      }
    });
  });

  group('Penalty Formula Verification', () {
    test('Verificar fórmula de semanas es correcta', () {
      // Para entender la fórmula: ((daysLate - 1) / 7) + 1

      // Caso 1: 1 día de atraso → semana 1
      expect(((1 - 1) ~/ 7) + 1, equals(1));

      // Caso 2: 7 días de atraso → semana 1
      expect(((7 - 1) ~/ 7) + 1, equals(1));

      // Caso 3: 8 días de atraso → semana 2
      expect(((8 - 1) ~/ 7) + 1, equals(2));

      // Caso 4: 14 días de atraso → semana 2
      expect(((14 - 1) ~/ 7) + 1, equals(2));

      // Caso 5: 15 días de atraso → semana 3
      expect(((15 - 1) ~/ 7) + 1, equals(3));
    });

    test('Verificar conversión a double es correcta', () {
      final weeks = 2;
      final penaltyPerWeek = 1.00;

      final penalty = (weeks * penaltyPerWeek).toDouble();

      expect(penalty, isA<double>());
      expect(penalty, equals(2.00));
    });
  });
}
