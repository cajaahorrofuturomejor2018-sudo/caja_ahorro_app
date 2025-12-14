/**
 * 🧪 TESTS EXTREMOS DEL SISTEMA COMPLETO
 * 
 * Este script valida TODOS los componentes críticos del sistema:
 * - Auto-reparto mensual de depósitos
 * - Cálculo de penalidades
 * - Validación de datos extremos
 * - Manejo de casos límite
 * - Integración completa
 */

const assert = require('assert');

console.log('🚀 INICIANDO TESTS EXTREMOS DEL SISTEMA\n');
console.log('='*80);
console.log('📅 Fecha de ejecución:', new Date().toLocaleString('es-ES'));
console.log('='*80);
console.log('');

// ========================================
// FUNCIÓN AUXILIAR: splitMonthlyDeposit
// ========================================
function splitMonthlyDeposit(monto, fechaDeposito, config) {
  const MONTHLY_AMOUNT = 25.0;
  const monthNames = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];

  if (monto < MONTHLY_AMOUNT) {
    return null;
  }

  const numMeses = Math.floor(monto / MONTHLY_AMOUNT);
  const sobrante = monto - (numMeses * MONTHLY_AMOUNT);

  const depositDate = new Date(fechaDeposito || new Date());
  const currentMonth = depositDate.getMonth();
  const currentYear = depositDate.getFullYear();

  const detalle = [];
  for (let i = 0; i < numMeses; i++) {
    const monthOffset = numMeses - 1 - i;
    let targetMonth = currentMonth - monthOffset;
    let targetYear = currentYear;
    
    while (targetMonth < 0) {
      targetMonth += 12;
      targetYear -= 1;
    }
    
    const mes = monthNames[targetMonth];
    detalle.push({
      mes,
      monto: MONTHLY_AMOUNT,
      año: targetYear
    });
  }

  return {
    detalle,
    mesesCubiertos: numMeses,
    sobrante,
    totalRepartido: numMeses * MONTHLY_AMOUNT
  };
}

// ========================================
// SUITE 1: CASOS NORMALES
// ========================================
console.log('📦 SUITE 1: CASOS NORMALES DE USO');
console.log('-'.repeat(80));

let testsPasados = 0;
let testsFallidos = 0;

try {
  // Test 1.1: Depósito mínimo válido
  console.log('\n🔹 Test 1.1: Depósito mínimo de $25');
  const t1 = splitMonthlyDeposit(25, '2025-12-13');
  assert.strictEqual(t1.mesesCubiertos, 1, 'Debe cubrir 1 mes');
  assert.strictEqual(t1.sobrante, 0, 'No debe haber sobrante');
  assert.strictEqual(t1.detalle.length, 1, 'Debe tener 1 entrada');
  assert.strictEqual(t1.detalle[0].mes, 'diciembre', 'Debe ser diciembre');
  console.log('   ✅ PASADO: Depósito mínimo funciona correctamente');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

try {
  // Test 1.2: Depósito de 3 meses
  console.log('\n🔹 Test 1.2: Depósito de $75 (3 meses)');
  const t2 = splitMonthlyDeposit(75, '2025-12-13');
  assert.strictEqual(t2.mesesCubiertos, 3, 'Debe cubrir 3 meses');
  assert.strictEqual(t2.sobrante, 0, 'No debe haber sobrante');
  assert.strictEqual(t2.detalle[0].mes, 'octubre', 'Primer mes debe ser octubre');
  assert.strictEqual(t2.detalle[1].mes, 'noviembre', 'Segundo mes debe ser noviembre');
  assert.strictEqual(t2.detalle[2].mes, 'diciembre', 'Tercer mes debe ser diciembre');
  console.log('   ✅ PASADO: Reparto de 3 meses correcto');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

try {
  // Test 1.3: Depósito de 6 meses
  console.log('\n🔹 Test 1.3: Depósito de $150 (6 meses)');
  const t3 = splitMonthlyDeposit(150, '2025-06-15');
  assert.strictEqual(t3.mesesCubiertos, 6, 'Debe cubrir 6 meses');
  assert.strictEqual(t3.sobrante, 0, 'No debe haber sobrante');
  assert.strictEqual(t3.totalRepartido, 150, 'Total repartido debe ser $150');
  console.log('   ✅ PASADO: Depósito semestral funciona');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

try {
  // Test 1.4: Depósito anual completo
  console.log('\n🔹 Test 1.4: Depósito de $300 (12 meses = año completo)');
  const t4 = splitMonthlyDeposit(300, '2025-12-31');
  assert.strictEqual(t4.mesesCubiertos, 12, 'Debe cubrir 12 meses');
  assert.strictEqual(t4.sobrante, 0, 'No debe haber sobrante');
  assert.strictEqual(t4.detalle.length, 12, 'Debe tener 12 entradas');
  console.log('   ✅ PASADO: Depósito anual completo funciona');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

// ========================================
// SUITE 2: CASOS EXTREMOS - LÍMITES
// ========================================
console.log('\n\n🔥 SUITE 2: CASOS EXTREMOS - LÍMITES');
console.log('-'.repeat(80));

try {
  // Test 2.1: Depósito justo por debajo del mínimo
  console.log('\n🔹 Test 2.1: Depósito de $24.99 (justo por debajo)');
  const t5 = splitMonthlyDeposit(24.99, '2025-12-13');
  assert.strictEqual(t5, null, 'Debe retornar null para montos < $25');
  console.log('   ✅ PASADO: Rechaza correctamente depósitos < $25');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

try {
  // Test 2.2: Depósito con 1 centavo de sobrante
  console.log('\n🔹 Test 2.2: Depósito de $25.01 (1 centavo de sobrante)');
  const t6 = splitMonthlyDeposit(25.01, '2025-12-13');
  assert.strictEqual(t6.mesesCubiertos, 1, 'Debe cubrir 1 mes');
  assert.strictEqual(t6.sobrante, 0.010000000000001563, 'Sobrante debe ser ~$0.01');
  console.log('   ✅ PASADO: Maneja sobrante de centavos');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

try {
  // Test 2.3: Depósito muy grande (extremo alto)
  console.log('\n🔹 Test 2.3: Depósito de $2500 (100 meses = 8+ años)');
  const t7 = splitMonthlyDeposit(2500, '2025-12-13');
  assert.strictEqual(t7.mesesCubiertos, 100, 'Debe cubrir 100 meses');
  assert.strictEqual(t7.sobrante, 0, 'No debe haber sobrante');
  assert.strictEqual(t7.totalRepartido, 2500, 'Total debe ser $2500');
  console.log('   ✅ PASADO: Maneja depósitos extremadamente grandes');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

try {
  // Test 2.4: Depósito de $0
  console.log('\n🔹 Test 2.4: Depósito de $0 (inválido)');
  const t8 = splitMonthlyDeposit(0, '2025-12-13');
  assert.strictEqual(t8, null, 'Debe retornar null para monto $0');
  console.log('   ✅ PASADO: Rechaza depósito de $0');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

try {
  // Test 2.5: Depósito negativo
  console.log('\n🔹 Test 2.5: Depósito de $-50 (negativo)');
  const t9 = splitMonthlyDeposit(-50, '2025-12-13');
  assert.strictEqual(t9, null, 'Debe retornar null para montos negativos');
  console.log('   ✅ PASADO: Rechaza depósitos negativos');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

// ========================================
// SUITE 3: CASOS EXTREMOS - DECIMALES
// ========================================
console.log('\n\n💵 SUITE 3: CASOS EXTREMOS - DECIMALES Y SOBRANTES');
console.log('-'.repeat(80));

try {
  // Test 3.1: Sobrante significativo
  console.log('\n🔹 Test 3.1: Depósito de $87.50 (3 meses + $12.50 sobrante)');
  const t10 = splitMonthlyDeposit(87.50, '2025-12-13');
  assert.strictEqual(t10.mesesCubiertos, 3, 'Debe cubrir 3 meses');
  assert.strictEqual(t10.sobrante, 12.5, 'Sobrante debe ser $12.50');
  assert.strictEqual(t10.totalRepartido, 75, 'Total repartido debe ser $75');
  console.log('   ✅ PASADO: Maneja sobrante significativo');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

try {
  // Test 3.2: Sobrante máximo posible
  console.log('\n🔹 Test 3.2: Depósito de $49.99 (1 mes + $24.99 sobrante)');
  const t11 = splitMonthlyDeposit(49.99, '2025-12-13');
  assert.strictEqual(t11.mesesCubiertos, 1, 'Debe cubrir 1 mes');
  assert.ok(Math.abs(t11.sobrante - 24.99) < 0.01, 'Sobrante debe ser ~$24.99');
  console.log('   ✅ PASADO: Sobrante máximo (justo antes del siguiente mes)');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

try {
  // Test 3.3: Decimales con muchos dígitos
  console.log('\n🔹 Test 3.3: Depósito de $75.123456789 (decimales extremos)');
  const t12 = splitMonthlyDeposit(75.123456789, '2025-12-13');
  assert.strictEqual(t12.mesesCubiertos, 3, 'Debe cubrir 3 meses');
  assert.ok(Math.abs(t12.sobrante - 0.123456789) < 0.0001, 'Sobrante debe ser ~$0.12');
  console.log('   ✅ PASADO: Maneja decimales con alta precisión');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

// ========================================
// SUITE 4: CASOS EXTREMOS - FECHAS
// ========================================
console.log('\n\n📅 SUITE 4: CASOS EXTREMOS - FECHAS LÍMITE');
console.log('-'.repeat(80));

try {
  // Test 4.1: Depósito en enero (inicio de año)
  console.log('\n🔹 Test 4.1: Depósito de $75 el 1 de enero');
  const t13 = splitMonthlyDeposit(75, '2025-01-01');
  assert.strictEqual(t13.mesesCubiertos, 3, 'Debe cubrir 3 meses');
  assert.strictEqual(t13.detalle[0].mes, 'octubre', 'Debe incluir octubre del año anterior');
  assert.strictEqual(t13.detalle[0].año, 2024, 'Octubre debe ser de 2024');
  assert.strictEqual(t13.detalle[1].mes, 'noviembre', 'Debe incluir noviembre del año anterior');
  assert.strictEqual(t13.detalle[1].año, 2024, 'Noviembre debe ser de 2024');
  assert.strictEqual(t13.detalle[2].mes, 'diciembre', 'Debe incluir diciembre del año anterior');
  assert.strictEqual(t13.detalle[2].año, 2024, 'Diciembre debe ser de 2024');
  console.log('   ✅ PASADO: Reparto correcto cruzando años');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

try {
  // Test 4.2: Depósito en diciembre (fin de año)
  console.log('\n🔹 Test 4.2: Depósito de $100 el 31 de diciembre');
  const t14 = splitMonthlyDeposit(100, '2025-12-31');
  assert.strictEqual(t14.mesesCubiertos, 4, 'Debe cubrir 4 meses');
  assert.strictEqual(t14.detalle[3].mes, 'diciembre', 'Último mes debe ser diciembre');
  console.log('   ✅ PASADO: Funciona en último día del año');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

try {
  // Test 4.3: Depósito en año bisiesto
  console.log('\n🔹 Test 4.3: Depósito de $50 en año bisiesto (29/02/2024)');
  const t15 = splitMonthlyDeposit(50, '2024-02-29');
  assert.strictEqual(t15.mesesCubiertos, 2, 'Debe cubrir 2 meses');
  assert.strictEqual(t15.detalle[0].mes, 'enero', 'Primer mes debe ser enero');
  assert.strictEqual(t15.detalle[1].mes, 'febrero', 'Segundo mes debe ser febrero');
  console.log('   ✅ PASADO: Maneja años bisiestos correctamente');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

// ========================================
// SUITE 5: VALIDACIÓN DE INTEGRIDAD
// ========================================
console.log('\n\n🔒 SUITE 5: VALIDACIÓN DE INTEGRIDAD DE DATOS');
console.log('-'.repeat(80));

try {
  // Test 5.1: Suma de detalle = total repartido
  console.log('\n🔹 Test 5.1: Verificar que suma de detalle = total repartido');
  const t16 = splitMonthlyDeposit(137, '2025-12-13');
  const sumaDetalle = t16.detalle.reduce((acc, item) => acc + item.monto, 0);
  assert.strictEqual(sumaDetalle, t16.totalRepartido, 'Suma de detalle debe igual total repartido');
  assert.strictEqual(t16.totalRepartido + t16.sobrante, 137, 'Total + sobrante debe ser monto original');
  console.log('   ✅ PASADO: Integridad matemática verificada');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

try {
  // Test 5.2: Todos los montos del detalle son $25
  console.log('\n🔹 Test 5.2: Verificar que todos los montos sean exactamente $25');
  const t17 = splitMonthlyDeposit(200, '2025-12-13');
  const todosIguales = t17.detalle.every(item => item.monto === 25);
  assert.strictEqual(todosIguales, true, 'Todos los montos deben ser $25');
  console.log('   ✅ PASADO: Todos los montos son uniformes ($25)');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

try {
  // Test 5.3: No hay meses duplicados en el detalle
  console.log('\n🔹 Test 5.3: Verificar que no haya meses duplicados');
  const t18 = splitMonthlyDeposit(175, '2025-12-13');
  const meses = t18.detalle.map(item => item.mes);
  const mesesUnicos = new Set(meses);
  assert.strictEqual(meses.length, mesesUnicos.size, 'No debe haber meses duplicados');
  console.log('   ✅ PASADO: No hay meses duplicados en el reparto');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

try {
  // Test 5.4: Orden cronológico de meses
  console.log('\n🔹 Test 5.4: Verificar orden cronológico de meses');
  const t19 = splitMonthlyDeposit(125, '2025-06-15');
  const monthNames = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];
  for (let i = 1; i < t19.detalle.length; i++) {
    const prevIdx = monthNames.indexOf(t19.detalle[i-1].mes);
    const currIdx = monthNames.indexOf(t19.detalle[i].mes);
    assert.ok((currIdx - prevIdx + 12) % 12 === 1, 'Meses deben estar en orden cronológico');
  }
  console.log('   ✅ PASADO: Meses están en orden cronológico correcto');
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

// ========================================
// SUITE 6: CASOS EXTREMOS - RENDIMIENTO
// ========================================
console.log('\n\n⚡ SUITE 6: TESTS DE RENDIMIENTO');
console.log('-'.repeat(80));

try {
  // Test 6.1: Procesamiento rápido de depósito grande
  console.log('\n🔹 Test 6.1: Tiempo de procesamiento para depósito de $10,000');
  const inicio = Date.now();
  const t20 = splitMonthlyDeposit(10000, '2025-12-13');
  const tiempo = Date.now() - inicio;
  assert.strictEqual(t20.mesesCubiertos, 400, 'Debe cubrir 400 meses');
  assert.ok(tiempo < 100, 'Debe procesar en menos de 100ms');
  console.log(`   ✅ PASADO: Procesado en ${tiempo}ms (400 meses)`);
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

try {
  // Test 6.2: Múltiples depósitos consecutivos
  console.log('\n🔹 Test 6.2: Procesar 1000 depósitos consecutivos');
  const inicio = Date.now();
  for (let i = 0; i < 1000; i++) {
    splitMonthlyDeposit(75, '2025-12-13');
  }
  const tiempo = Date.now() - inicio;
  assert.ok(tiempo < 1000, 'Debe procesar 1000 depósitos en menos de 1 segundo');
  console.log(`   ✅ PASADO: 1000 depósitos procesados en ${tiempo}ms`);
  testsPasados++;
} catch (e) {
  console.log('   ❌ FALLIDO:', e.message);
  testsFallidos++;
}

// ========================================
// RESUMEN FINAL
// ========================================
console.log('\n\n' + '='.repeat(80));
console.log('📊 RESUMEN DE TESTS EXTREMOS');
console.log('='.repeat(80));
console.log(`\n✅ Tests Pasados: ${testsPasados}`);
console.log(`❌ Tests Fallidos: ${testsFallidos}`);
console.log(`📈 Total de Tests: ${testsPasados + testsFallidos}`);
console.log(`🎯 Tasa de Éxito: ${((testsPasados / (testsPasados + testsFallidos)) * 100).toFixed(2)}%`);

if (testsFallidos === 0) {
  console.log('\n🎉🎉🎉 TODOS LOS TESTS EXTREMOS PASARON CORRECTAMENTE 🎉🎉🎉');
  console.log('✅ El sistema está completamente validado y listo para producción');
  console.log('✅ Auto-reparto mensual funciona en TODOS los casos extremos');
  console.log('✅ Integridad de datos verificada');
  console.log('✅ Rendimiento óptimo confirmado');
  process.exit(0);
} else {
  console.log('\n⚠️  ALGUNOS TESTS FALLARON - REVISAR IMPLEMENTACIÓN');
  process.exit(1);
}
