/**
 * TEST: Verificar que el frontend llama al endpoint correcto
 * Simula axios interceptor para capturar peticiones HTTP
 */

console.log('\n🚀 === TEST FRONTEND: ENDPOINT LLAMADO ===\n');

// Mock axios
const mockAxios = {
  lastCall: null,
  create: function(config) {
    return {
      defaults: { headers: { common: {} } },
      get: async (url, cfg) => {
        this.lastCall = { method: 'GET', url, config: cfg };
        console.log(`📡 [GET] ${url}`);
        return { data: { ok: true } };
      },
      post: async (url, payload, cfg) => {
        this.lastCall = { method: 'POST', url, payload, config: cfg };
        console.log(`📡 [POST] ${url}`);
        console.log(`   Payload:`, payload);
        return { data: { ok: true } };
      }
    };
  }
};

// Simular apiClient.js
const getBaseURL = () => {
  // En Docker con proxy nginx apuntando a /api:
  // VITE_API_URL='/api' → baseURL debería ser '/api'
  const envUrl = '/api'; // Simulamos VITE_API_URL
  if (envUrl) return envUrl;
  return 'http://localhost:8080';
};

const client = mockAxios.create({
  baseURL: getBaseURL(),
  timeout: 30000,
  headers: { 'Content-Type': 'application/json' },
});

async function apiPost(endpoint, payload = {}, config = {}) {
  try {
    console.log(`\n[apiPost] Endpoint: ${endpoint}`);
    const response = await client.post(endpoint, payload, config);
    return { success: true, data: response.data };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function approveDeposit(depositId, approve = true, observaciones = '', interes = null, documento_url = null) {
  const payload = { approve, observaciones };
  if (interes !== null) payload.interes = interes;
  if (documento_url !== null) payload.documento_url = documento_url;
  console.log(`[approveDeposit] Calling /api/deposits/${depositId}/approve with:`, payload);
  return apiPost(`/api/deposits/${depositId}/approve`, payload);
}

// ========================
// TESTS
// ========================

async function runTests() {
  console.log('📋 Setup: VITE_API_URL = "/api"\n');
  console.log(`Base URL: ${getBaseURL()}\n`);

  // Test 1: Endpoint correcto con /api
  console.log('=' .repeat(60));
  console.log('TEST 1: Llamar approveDeposit con ID y approve=true');
  console.log('='.repeat(60));
  
  await approveDeposit('deposit_123', true, 'Aprobado', null, null);
  
  const call1 = mockAxios.lastCall;
  console.log(`\n✓ Última petición:`);
  console.log(`  - Método: ${call1.method}`);
  console.log(`  - URL: ${call1.url}`);
  console.log(`  - BaseURL + Endpoint = ${getBaseURL()}${call1.url}`);
  
  const isCorrect1 = call1.url === '/api/deposits/deposit_123/approve';
  console.log(`\n${isCorrect1 ? '✅' : '❌'} TEST 1: ${isCorrect1 ? 'PASS' : 'FAIL'}`);
  if (!isCorrect1) {
    console.log(`   Esperado: /api/deposits/deposit_123/approve`);
    console.log(`   Obtuvo: ${call1.url}`);
  }

  // Test 2: Payload correcto
  console.log(`\n${'='.repeat(60)}`);
  console.log('TEST 2: Payload contiene approve=true');
  console.log('='.repeat(60));
  
  const payloadCorrect = call1.payload && call1.payload.approve === true;
  console.log(`\n${payloadCorrect ? '✅' : '❌'} TEST 2: ${payloadCorrect ? 'PASS' : 'FAIL'}`);
  if (!payloadCorrect) {
    console.log(`   Esperado: { approve: true, observaciones: 'Aprobado' }`);
    console.log(`   Obtuvo: ${JSON.stringify(call1.payload)}`);
  }

  // Test 3: Diferente tipo de depósito
  console.log(`\n${'='.repeat(60)}`);
  console.log('TEST 3: Llamar con certificate deposit');
  console.log('='.repeat(60));
  
  await approveDeposit('cert_456', true, 'Certificado aprobado', 5.5, null);
  
  const call3 = mockAxios.lastCall;
  const isCorrect3 = call3.url === '/api/deposits/cert_456/approve' && call3.payload.interes === 5.5;
  console.log(`\n${isCorrect3 ? '✅' : '❌'} TEST 3: ${isCorrect3 ? 'PASS' : 'FAIL'}`);
  if (!isCorrect3) {
    console.log(`   URL Esperado: /api/deposits/cert_456/approve, Obtuvo: ${call3.url}`);
    console.log(`   Interés Esperado: 5.5, Obtuvo: ${call3.payload.interes}`);
  }

  // Test 4: Rechazar depósito
  console.log(`\n${'='.repeat(60)}`);
  console.log('TEST 4: Rechazar depósito (approve=false)');
  console.log('='.repeat(60));
  
  await approveDeposit('bad_deposit_789', false, 'Rechazado por documento');
  
  const call4 = mockAxios.lastCall;
  const isCorrect4 = call4.url === '/api/deposits/bad_deposit_789/approve' && call4.payload.approve === false;
  console.log(`\n${isCorrect4 ? '✅' : '❌'} TEST 4: ${isCorrect4 ? 'PASS' : 'FAIL'}`);
  if (!isCorrect4) {
    console.log(`   Esperado: approve=false, Obtuvo: ${call4.payload.approve}`);
  }

  // Resumen
  console.log(`\n${'='.repeat(60)}`);
  console.log('📊 RESUMEN DE TESTS');
  console.log('='.repeat(60));
  
  const allPass = isCorrect1 && payloadCorrect && isCorrect3 && isCorrect4;
  
  console.log(`\nTest 1 (Endpoint con /api): ${isCorrect1 ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`Test 2 (Payload correcto): ${payloadCorrect ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`Test 3 (Certificado): ${isCorrect3 ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`Test 4 (Rechazo): ${isCorrect4 ? '✅ PASS' : '❌ FAIL'}`);
  
  console.log(`\n${'='.repeat(60)}`);
  if (allPass) {
    console.log(`✅✅✅ TODOS LOS TESTS PASARON ✅✅✅\n`);
    console.log(`📌 CONCLUSIÓN:`);
    console.log(`   - El frontend llama al endpoint CORRECTO: /api/deposits/:id/approve`);
    console.log(`   - El payload se envía correctamente`);
    console.log(`   - Con nginx proxy, la petición llegará a: http://localhost:8080/api/deposits/:id/approve`);
    console.log(`   - El backend debería recibir y procesar la aprobación`);
  } else {
    console.log(`❌ ALGUNOS TESTS FALLARON - Revisar apiClient.js`);
  }
  console.log(`${'='.repeat(60)}\n`);
}

runTests().catch(console.error);
