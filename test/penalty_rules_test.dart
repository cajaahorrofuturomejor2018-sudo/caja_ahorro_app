import 'package:flutter_test/flutter_test.dart';
import 'package:caja_ahorro_app/core/services/firestore_service.dart';

void main() {
  // Usar método estático para evitar necesidad de inicializar Firebase

  group('Penalty rules', () {
    test('ahorro on time -> no penalty', () {
      final dep = {
        'fecha_deposito_detectada': '2025-12-05',
        'tipo': 'ahorro',
        'monto': 100.0,
      };
      final cfg = {
        'enforce_voucher_date': true,
        'penalty_rules': {'ahorro_per_week': 1.0},
      };
      final p = FirestoreService.computePenaltyForDepositStatic(dep, cfg);
      expect(p, 0.0);
    });

    test('ahorro day 11 -> 1 USD', () {
      final dep = {
        'fecha_deposito_detectada': '2025-12-11',
        'tipo': 'ahorro',
        'monto': 100.0,
      };
      final cfg = {
        'enforce_voucher_date': true,
        'penalty_rules': {'ahorro_per_week': 1.0},
      };
      final p = FirestoreService.computePenaltyForDepositStatic(dep, cfg);
      expect(p, 1.0);
    });

    test('ahorro day 18 -> 2 USD', () {
      final dep = {
        'fecha_deposito_detectada': '2025-12-18',
        'tipo': 'ahorro',
        'monto': 100.0,
      };
      final cfg = {
        'enforce_voucher_date': true,
        'penalty_rules': {'ahorro_per_week': 1.0},
      };
      final p = FirestoreService.computePenaltyForDepositStatic(dep, cfg);
      expect(p, 2.0);
    });

    test('pago_prestamo within 1-15 days -> 7%', () {
      final dep = {
        'fecha_deposito_detectada': '2025-12-12',
        'tipo': 'pago_prestamo',
        'monto': 200.0,
      };
      final cfg = {'enforce_voucher_date': true};
      final p = FirestoreService.computePenaltyForDepositStatic(dep, cfg);
      expect(p, closeTo(200.0 * 0.07, 0.0001));
    });

    test('pago_prestamo within 16-30 days -> 10%', () {
      final dep = {
        'fecha_deposito_detectada': '2025-12-26',
        'tipo': 'pago_prestamo',
        'monto': 150.0,
      };
      final cfg = {'enforce_voucher_date': true};
      final p = FirestoreService.computePenaltyForDepositStatic(dep, cfg);
      expect(p, closeTo(150.0 * 0.10, 0.0001));
    });
  });
}
