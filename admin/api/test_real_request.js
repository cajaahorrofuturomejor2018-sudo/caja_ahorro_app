/**
 * TEST REAL: Simular una petición REAL POST /api/deposits/:id/approve
 * Como si viniera del navegador
 */

const http = require('http');

console.log('\n🚀 === TEST DE PETICIÓN REAL AL API ===\n');

function makeRequest(method, path, payload, token) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 8080,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token || 'fake-token-test'}`
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        console.log(`\n📡 Response Status: ${res.statusCode}`);
        console.log(`Headers:`, res.headers);
        
        try {
          if (data) {
            const json = JSON.parse(data);
            console.log(`Body:`, JSON.stringify(json, null, 2));
          }
        } catch (e) {
          console.log(`Body:`, data);
        }
        
        resolve({ status: res.statusCode, data });
      });
    });

    req.on('error', (e) => {
      console.error(`❌ Request Error:`, e);
      reject(e);
    });

    if (payload) {
      req.write(JSON.stringify(payload));
    }
    req.end();
  });
}

async function runTest() {
  try {
    console.log('Enviando petición POST a /api/deposits/test-123/approve...\n');
    
    const response = await makeRequest(
      'POST',
      '/api/deposits/test-123/approve',
      { approve: true, observaciones: 'Test desde CLI' },
      'fake-token-for-test'  // Token falso - debería fallar en verificación
    );

    console.log('\n✅ Petición completada');
    console.log(`Status: ${response.status}`);
    
    if (response.status === 403) {
      console.log('\n📌 Esperado: 403 Forbidden (token inválido)');
      console.log('   Esto confirma que el endpoint SÍ está siendo llamado');
    } else if (response.status === 500) {
      console.log('\n⚠️  Error 500: Algo mal en el backend');
      console.log('   Revisar logs del API');
    } else if (response.status === 200) {
      console.log('\n✅ Éxito 200: Depósito procesado');
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

runTest();
