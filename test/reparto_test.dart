import 'package:flutter_test/flutter_test.dart';
import 'package:caja_ahorro_app/core/services/firestore_service.dart';

void main() {
  group('computeEqualSplit', () {
    test('distributes cents evenly and sums to total (10.00 / 3)', () {
      final uids = ['u1', 'u2', 'u3'];
      final reparto = FirestoreService.computeEqualSplit(10.00, uids);
      expect(reparto.length, equals(3));
      final montos = reparto.map((e) => e['monto'] as double).toList();
      // expected 3.34, 3.33, 3.33
      expect(montos[0], equals(3.34));
      expect(montos[1], equals(3.33));
      expect(montos[2], equals(3.33));
      final sum = montos.reduce((a, b) => a + b);
      expect((sum * 100).round(), equals(1000));
    });

    test('small amount where some get zero (0.01 / 2)', () {
      final uids = ['a', 'b'];
      final reparto = FirestoreService.computeEqualSplit(0.01, uids);
      expect(reparto.length, equals(2));
      final montos = reparto.map((e) => e['monto'] as double).toList();
      expect(montos[0], equals(0.01));
      expect(montos[1], equals(0.0));
      final sum = montos.reduce((a, b) => a + b);
      expect((sum * 100).round(), equals(1));
    });

    test('exact division (9.00 / 3)', () {
      final uids = ['x', 'y', 'z'];
      final reparto = FirestoreService.computeEqualSplit(9.00, uids);
      final montos = reparto.map((e) => e['monto'] as double).toList();
      expect(montos, equals([3.0, 3.0, 3.0]));
      final sum = montos.reduce((a, b) => a + b);
      expect((sum * 100).round(), equals(900));
    });
  });
}
