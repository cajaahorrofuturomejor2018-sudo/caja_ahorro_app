/// Script de validación de lógica de multas (penalty system)
/// Ejecutar con: dart scripts/validate_penalty_logic.dart
///
/// Verifica que:
/// - Ahorro: $1 por semana (7 días) a partir del día 11
/// - Pago préstamo: 7% días 1-15, 10% días 16-30, acumula 10% después de 30
/// - Fechas se calculan correctamente basadas en día del mes

void main() {
  print('=== PENALTY SYSTEM LOGIC VALIDATION ===\n');

  // Simulate penalty calculation
  double calculatePenalty(
    String tipo,
    double monto,
    int dayOfMonth, {
    Map<String, dynamic>? config,
  }) {
    config ??= {'enforce_voucher_date': true, 'penalty_rules': {}};

    final enforceDate = config['enforce_voucher_date'] ?? false;
    if (!enforceDate) return 0.0;

    // If deposit is on day 1-10, it's on time
    if (dayOfMonth <= 10) return 0.0;

    // Calculate days late starting from day 11
    final daysLate = dayOfMonth - 10;

    // Ahorro: $1 per each started 7-day period
    if (tipo == 'ahorro' || tipo == 'ahorro_voluntario') {
      // Formula: 1-7 days = 1 week, 8-14 days = 2 weeks, etc.
      final weeks = ((daysLate - 1) ~/ 7) + 1;
      final penaltyPerWeek =
          (config['penalty_rules']?['ahorro_per_week'] ?? 1.0).toDouble();
      print('[DEBUG] Ahorro: daysLate=$daysLate, weeks=$weeks');
      return (weeks * penaltyPerWeek) as double;
    }

    // Pago préstamo: tiered percentages
    if (tipo == 'pago_prestamo') {
      if (daysLate <= 15) {
        print('[DEBUG] Pago: daysLate=$daysLate <= 15, returning 7%');
        return monto * 0.07; // 7%
      }
      if (daysLate <= 30) {
        print('[DEBUG] Pago: daysLate=$daysLate <= 30, returning 10%');
        return monto * 0.10; // 10%
      }
      if (daysLate > 30) {
        final periods = ((daysLate - 1) ~/ 30) + 1;
        print('[DEBUG] Pago: daysLate=$daysLate > 30, periods=$periods');
        return monto * 0.10 * periods; // accumulates 10% per 30 days
      }
    }

    return 0.0;
  }

  int passCount = 0;
  int failCount = 0;

  // Test case helper
  void testCase(
    String desc,
    String tipo,
    double monto,
    int dayOfMonth,
    double expected, {
    Map<String, dynamic>? config,
  }) {
    final result = calculatePenalty(tipo, monto, dayOfMonth, config: config);
    final passed = (result - expected).abs() < 0.01;
    final status = passed ? '✓ PASS' : '✗ FAIL';

    print('$status: $desc');
    print(
      '  Type: $tipo | Day: $dayOfMonth | Monto: \$${monto.toStringAsFixed(2)}',
    );
    print(
      '  Expected: \$${expected.toStringAsFixed(2)} | Got: \$${result.toStringAsFixed(2)}',
    );
    print('');

    if (passed) {
      passCount++;
    } else {
      failCount++;
    }
  }

  // === AHORRO TESTS ===
  print('--- AHORRO MENSUAL TESTS (Deadline: Day 10) ---\n');

  testCase('Ahorro: Day 10 (on time)', 'ahorro', 100.0, 10, 0.0);

  testCase(
    'Ahorro: Day 11 (1 day late = 1 week) = \$1',
    'ahorro',
    100.0,
    11,
    1.0,
  );

  testCase(
    'Ahorro: Day 17 (7 days late = 1 week complete)',
    'ahorro',
    100.0,
    17,
    1.0,
  );

  testCase(
    'Ahorro: Day 18 (8 days late = 2 weeks) = \$2',
    'ahorro',
    100.0,
    18,
    2.0,
  );

  testCase(
    'Ahorro: Day 25 (15 days late = 3 weeks) = \$3',
    'ahorro',
    100.0,
    25,
    3.0,
  );

  testCase(
    'Ahorro: Day 25 with custom \$2.50/week = \$7.50',
    'ahorro',
    100.0,
    25,
    7.50,
    config: {
      'enforce_voucher_date': true,
      'penalty_rules': {'ahorro_per_week': 2.5},
    },
  );

  // === PAGO PRÉSTAMO TESTS ===
  print('\n--- PAGO PRÉSTAMO TESTS (Deadline: Day 10) ---\n');

  testCase('Pago préstamo: Day 10 (on time)', 'pago_prestamo', 100.0, 10, 0.0);

  testCase(
    'Pago préstamo: Day 11 (1 day late, 7% tier) = \$7',
    'pago_prestamo',
    100.0,
    11,
    7.0,
  );

  testCase(
    'Pago préstamo: Day 15 (5 days late, 7% tier) = \$7',
    'pago_prestamo',
    100.0,
    15,
    7.0,
  );

  testCase(
    'Pago préstamo: Day 16 (=dayOfMonth) is 6 days late, still in 1-15 range = \$7',
    'pago_prestamo',
    100.0,
    16,
    7.0,
  );

  testCase(
    'Pago préstamo: Day 26 (=dayOfMonth) is 16 days late, enters 16-30 range = \$10',
    'pago_prestamo',
    100.0,
    26,
    10.0,
  );

  testCase(
    'Pago préstamo: Day 30 (20 days late, 10% tier) = \$10',
    'pago_prestamo',
    100.0,
    30,
    10.0,
  );

  testCase(
    'Pago préstamo: Day 31 (21 days late, still 10% tier) = \$10',
    'pago_prestamo',
    100.0,
    31,
    10.0,
  );

  testCase(
    'Pago préstamo: Day 40 (30 days late, accumulates: 1 period * 10%) = \$10',
    'pago_prestamo',
    100.0,
    40,
    10.0,
  );

  testCase(
    'Pago préstamo: Day 41 (31 days late, 2 periods * 10%) = \$20',
    'pago_prestamo',
    100.0,
    41,
    20.0,
  );

  testCase(
    'Pago préstamo: Large cuota \$500, Day 12 (7% tier) = \$35',
    'pago_prestamo',
    500.0,
    12,
    35.0,
  );

  testCase(
    'Pago préstamo: Large cuota \$500, Day 20 (=dayOfMonth) is 10 days late, 7% = \$35',
    'pago_prestamo',
    500.0,
    20,
    35.0,
  );

  testCase(
    'Pago préstamo: Large cuota \$500, Day 26 (=dayOfMonth) is 16 days late, 10% = \$50',
    'pago_prestamo',
    500.0,
    26,
    50.0,
  );

  testCase(
    'Pago préstamo: Large cuota \$500, Day 41 (2 periods * 10%) = \$100',
    'pago_prestamo',
    500.0,
    41,
    100.0,
  );

  // === ENFORCEMENT DISABLED ===
  print('\n--- ENFORCEMENT DISABLED TEST ---\n');

  testCase(
    'Enforcement disabled: No penalty even if late',
    'ahorro',
    100.0,
    25,
    0.0,
    config: {'enforce_voucher_date': false, 'penalty_rules': {}},
  );

  // === SUMMARY ===
  print('\n' + '=' * 50);
  print('SUMMARY');
  print('=' * 50);
  print('Passed: $passCount tests');
  print('Failed: $failCount tests');
  print('Total:  ${passCount + failCount} tests');

  if (failCount == 0) {
    print('\n✓ ALL TESTS PASSED - Penalty logic is correct!');
    return;
  } else {
    print('\n✗ SOME TESTS FAILED - Review penalty logic!');
  }
}
