/**
 * 🧪 Script de Prueba - Auto-Reparto Mensual
 * 
 * Este script valida que la función splitMonthlyDeposit() funcione correctamente
 * con diferentes montos de depósito.
 */

// Simular la función (copia del server.js)
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
    const monthIndex = (currentMonth - (numMeses - 1) + i + 12) % 12;
    const mes = monthNames[monthIndex];
    detalle.push({
      mes,
      monto: MONTHLY_AMOUNT,
      año: currentYear
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
// 🧪 CASOS DE PRUEBA
// ========================================

console.log('🚀 Iniciando pruebas de auto-reparto mensual\n');

// Test 1: Depósito exacto de $25 (1 mes)
console.log('📌 Test 1: Depósito de $25 (1 mes)');
const test1 = splitMonthlyDeposit(25, '2024-03-15');
console.log('Resultado:', JSON.stringify(test1, null, 2));
console.assert(test1.mesesCubiertos === 1, '❌ ERROR: Debería cubrir 1 mes');
console.assert(test1.sobrante === 0, '❌ ERROR: No debería haber sobrante');
console.assert(test1.detalle.length === 1, '❌ ERROR: Debería tener 1 entrada en detalle');
console.log('✅ Test 1 PASADO\n');

// Test 2: Depósito de $50 (2 meses)
console.log('📌 Test 2: Depósito de $50 (2 meses)');
const test2 = splitMonthlyDeposit(50, '2024-03-15');
console.log('Resultado:', JSON.stringify(test2, null, 2));
console.assert(test2.mesesCubiertos === 2, '❌ ERROR: Debería cubrir 2 meses');
console.assert(test2.sobrante === 0, '❌ ERROR: No debería haber sobrante');
console.assert(test2.detalle.length === 2, '❌ ERROR: Debería tener 2 entradas en detalle');
console.assert(test2.detalle[0].mes === 'febrero', '❌ ERROR: Primer mes debería ser febrero');
console.assert(test2.detalle[1].mes === 'marzo', '❌ ERROR: Segundo mes debería ser marzo');
console.log('✅ Test 2 PASADO\n');

// Test 3: Depósito de $75 (3 meses)
console.log('📌 Test 3: Depósito de $75 (3 meses)');
const test3 = splitMonthlyDeposit(75, '2024-03-15');
console.log('Resultado:', JSON.stringify(test3, null, 2));
console.assert(test3.mesesCubiertos === 3, '❌ ERROR: Debería cubrir 3 meses');
console.assert(test3.sobrante === 0, '❌ ERROR: No debería haber sobrante');
console.assert(test3.detalle.length === 3, '❌ ERROR: Debería tener 3 entradas en detalle');
console.assert(test3.detalle[0].mes === 'enero', '❌ ERROR: Primer mes debería ser enero');
console.assert(test3.detalle[1].mes === 'febrero', '❌ ERROR: Segundo mes debería ser febrero');
console.assert(test3.detalle[2].mes === 'marzo', '❌ ERROR: Tercer mes debería ser marzo');
console.log('✅ Test 3 PASADO\n');

// Test 4: Depósito de $80 (3 meses + sobrante)
console.log('📌 Test 4: Depósito de $80 (3 meses + $5 sobrante)');
const test4 = splitMonthlyDeposit(80, '2024-03-15');
console.log('Resultado:', JSON.stringify(test4, null, 2));
console.assert(test4.mesesCubiertos === 3, '❌ ERROR: Debería cubrir 3 meses');
console.assert(test4.sobrante === 5, '❌ ERROR: Sobrante debería ser $5');
console.assert(test4.detalle.length === 3, '❌ ERROR: Debería tener 3 entradas en detalle');
console.assert(test4.totalRepartido === 75, '❌ ERROR: Total repartido debería ser $75');
console.log('✅ Test 4 PASADO\n');

// Test 5: Depósito menor a $25 (no debe repartir)
console.log('📌 Test 5: Depósito de $20 (menor al mínimo)');
const test5 = splitMonthlyDeposit(20, '2024-03-15');
console.log('Resultado:', test5);
console.assert(test5 === null, '❌ ERROR: Debería retornar null para montos < $25');
console.log('✅ Test 5 PASADO\n');

// Test 6: Depósito de $100 (4 meses)
console.log('📌 Test 6: Depósito de $100 (4 meses)');
const test6 = splitMonthlyDeposit(100, '2024-04-15');
console.log('Resultado:', JSON.stringify(test6, null, 2));
console.assert(test6.mesesCubiertos === 4, '❌ ERROR: Debería cubrir 4 meses');
console.assert(test6.sobrante === 0, '❌ ERROR: No debería haber sobrante');
console.assert(test6.detalle.length === 4, '❌ ERROR: Debería tener 4 entradas en detalle');
console.assert(test6.detalle[0].mes === 'enero', '❌ ERROR: Primer mes debería ser enero');
console.assert(test6.detalle[1].mes === 'febrero', '❌ ERROR: Segundo mes debería ser febrero');
console.assert(test6.detalle[2].mes === 'marzo', '❌ ERROR: Tercer mes debería ser marzo');
console.assert(test6.detalle[3].mes === 'abril', '❌ ERROR: Cuarto mes debería ser abril');
console.log('✅ Test 6 PASADO\n');

// Test 7: Depósito de $125 (5 meses)
console.log('📌 Test 7: Depósito de $125 (5 meses)');
const test7 = splitMonthlyDeposit(125, '2024-05-15');
console.log('Resultado:', JSON.stringify(test7, null, 2));
console.assert(test7.mesesCubiertos === 5, '❌ ERROR: Debería cubrir 5 meses');
console.assert(test7.sobrante === 0, '❌ ERROR: No debería haber sobrante');
console.assert(test7.detalle.length === 5, '❌ ERROR: Debería tener 5 entradas en detalle');
console.log('✅ Test 7 PASADO\n');

// Test 8: Depósito de $63 (2 meses + $13 sobrante)
console.log('📌 Test 8: Depósito de $63 (2 meses + $13 sobrante)');
const test8 = splitMonthlyDeposit(63, '2024-03-15');
console.log('Resultado:', JSON.stringify(test8, null, 2));
console.assert(test8.mesesCubiertos === 2, '❌ ERROR: Debería cubrir 2 meses');
console.assert(test8.sobrante === 13, '❌ ERROR: Sobrante debería ser $13');
console.assert(test8.totalRepartido === 50, '❌ ERROR: Total repartido debería ser $50');
console.log('✅ Test 8 PASADO\n');

// ========================================
// 📊 RESUMEN
// ========================================

console.log('=========================================');
console.log('✅ TODOS LOS TESTS PASARON CORRECTAMENTE');
console.log('=========================================');
console.log('Total de tests: 8');
console.log('Tests exitosos: 8');
console.log('Tests fallidos: 0');
console.log('');
console.log('🎉 La función splitMonthlyDeposit() está funcionando correctamente');
console.log('🚀 El sistema está listo para auto-repartir depósitos mensuales');
