# Guía de Solución de Problemas - Admin Dashboard

Soluciones rápidas para errores comunes.

## 🔴 Dashboard No Carga

### Síntoma: Página en blanco o error 500

**Verificaciones:**

1. Backend corriendo:
```bash
# En terminal:
cd admin/api
npm start

# Debería ver: "Server running on port 8080"
```

2. Frontend URL correcta:
```bash
# Verificar en admin/web/.env
VITE_API_URL=http://localhost:8080
```

3. Puerto no en uso:
```bash
# Windows PowerShell:
netstat -ano | findstr :8080

# Si hay algo, matar proceso:
taskkill /PID <PID> /F
```

---

## 🔴 Error: "API_URL is not defined"

**Causa:** Variable de entorno no configurada

**Solución:**
```bash
cd admin/web

# Crear .env desde template
cp .env.example .env

# Editar .env
cat .env
# Debe tener: VITE_API_URL=http://localhost:8080
```

Luego reiniciar Vite:
```bash
npm run dev
```

---

## 🔴 Error: "Invalid Firebase Config"

**Causa:** Credenciales de Firebase incorrectas o faltantes

**Solución:**

1. Copiar `serviceAccountKey.json` a `admin/api/`:
```bash
cp ~/Descargas/serviceAccountKey.json admin/api/
```

2. O configurar como variable de entorno:
```bash
# En admin/api/.env:
FIREBASE_CONFIG=/ruta/a/serviceAccountKey.json
```

3. Si usas MOCK (desarrollo sin Firebase):
```javascript
// En admin/api/server.js línea ~50
const MOCK_API = true; // Usar datos fake
```

---

## 🔴 Error 401: "Unauthorized"

**Causa:** Token expirado o inválido

**Solución:**

1. Hacer logout y login nuevamente:
   - Click "Cerrar sesión"
   - Ingresar credentials nuevamente
   - Token se renovará automáticamente

2. Limpiar localStorage:
```javascript
// En consola del navegador (F12)
localStorage.clear();
location.reload();
```

---

## 🔴 Error 403: "Forbidden"

**Causa:** Usuario no tiene rol admin

**Solución:**

1. Cambiar rol en Firestore:
   - Abrir [Firebase Console](https://console.firebase.google.com)
   - Firestore → Colección `users`
   - Buscar usuario
   - Editar campo `rol: "admin"`

O usar API:
```bash
curl -X POST http://localhost:8080/api/users/USER_ID/role \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role": "admin"}'
```

---

## 🔴 Depósitos no aparecen en lista

**Causa:** Backend no conectando a Firestore

**Verificaciones:**

1. Firestore está disponible:
```bash
# En consola Node.js (admin/api)
# Debería ver: "✅ Firebase Admin SDK initialized"
```

2. Base de datos tiene datos:
   - Abrir Firebase Console
   - Firestore → Colección `deposits`
   - Verificar que existan documentos

3. Filtros activos:
   - Algunos endpoints filtran por estado
   - Cambiar filtro en backend si es necesario

---

## 🔴 Cambios no se guardan

**Causa:** Error en transacción de Firestore

**Verificaciones:**

1. Ver error detallado en consola:
   - DevTools del navegador (F12)
   - Consola → buscar mensaje de error

2. Revisar logs del backend:
   - Terminal donde corre `npm start`
   - Ver línea de error exacta

3. Firestore tiene permisos:
   - Firebase Console → Firestore → Rules
   - Verificar que reglas permitan escritura

---

## 🔴 Tabla vacía pero sin error

**Causa:** Respuesta del API está vacía

**Solución:**

1. Verificar que hay datos en Firestore:
```bash
# En Firebase Console
# Firestore → Colecciones → Ver documentos
```

2. Revisar respuesta del API:
```bash
curl -X GET http://localhost:8080/api/deposits \
  -H "Authorization: Bearer TOKEN" | jq .
```

3. Si respuesta es `[]`, puede ser correcto (vacío)
   - Crear datos de prueba primero

---

## 🔴 Penalizaciones no calculadas

**Causa:** Lógica de multas desactivada o error en cálculo

**Verificaciones:**

1. Revisar lógica en `server.js` líneas 360-600
   ```javascript
   // Debe tener lógica de:
   // - Validar fecha límite (día 10)
   // - Calcular días de retraso
   // - Aplicar penalización correcta
   ```

2. Verificar en Firestore que penalizaciones se apliquen:
   - Después de aprobar depósito
   - Check colección `users` → campo `total_multas`

3. Revisar logs en Node.js:
   - Terminal donde corre API
   - Buscar "penalty" o "multa"

---

## 🔴 Login no funciona

**Causa:** Firebase Auth no configurado

**Solución:**

1. Verificar credenciales en `src/utils/firebaseConfig.js`:
```javascript
// Debe tener:
apiKey: "tu-api-key",
authDomain: "tu-proyecto.firebaseapp.com",
projectId: "tu-proyecto"
// ... resto de config
```

2. Actualizar con valores correctos de Firebase Console:
   - Project Settings → General
   - Copy config values

3. Crear usuario en Firebase:
   - Firebase Console → Authentication
   - Click "Create user"
   - Email + password

---

## 🔴 Componente no actualiza después de acción

**Causa:** Estado React no se actualiza

**Solución:**

Agregar `.catch()` y forzar refresh:
```javascript
async function save() {
  const result = await updateCaja(saldo);
  if (result.success) {
    // Esperar 500ms, luego recargar
    setTimeout(() => load(), 500);
  }
}
```

O usar `useCallback` si hay dependencias:
```javascript
const load = useCallback(async () => {
  // cargar datos
}, [user?.token]);
```

---

## 🔴 CORS Error

**Síntoma:** "Access to XMLHttpRequest blocked by CORS policy"

**Solución:**

En `admin/api/server.js`, agregar headers CORS:
```javascript
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});
```

Luego reiniciar Node.js:
```bash
npm start
```

---

## 🔴 Vite Hot Reload no funciona

**Causa:** Node_modules dañados o caché

**Solución:**

```bash
cd admin/web

# Limpiar caché
rm -rf node_modules package-lock.json

# Reinstalar
npm install

# Reiniciar
npm run dev
```

---

## 🔴 npm install falla

**Causa:** Versiones de paquetes incompatibles

**Solución:**

```bash
# Limpiar caché npm
npm cache clean --force

# Usar npm 8+
npm -v  # Debe ser >= 8.0.0

# Si es vieja, actualizar:
npm install -g npm@latest

# Intentar install de nuevo
npm install
```

---

## 🔴 "Cannot find module 'axios'"

**Causa:** Paquete no instalado

**Solución:**

```bash
cd admin/web
npm install axios
```

O reinstalar todo:
```bash
npm install
```

---

## 🔴 Firestore Rules Error

**Síntoma:** "Missing or insufficient permissions"

**Solución:**

Abrir Firebase Console → Firestore → Rules

Reemplazar con reglas permisivas (solo para desarrollo):
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

Publicar reglas → Deploy

⚠️ **IMPORTANTE:** Estas son solo para desarrollo. En producción, usar reglas restrictivas por colección.

---

## 🟡 Performance Lenta

**Síntoma:** Tabla tarda en cargar

**Optimizaciones:**

1. Paginar resultados:
```javascript
// En apiClient.js
export async function fetchDeposits(limit = 50, startAfter = null) {
  // Implementar pagination
}
```

2. Cachear datos:
```javascript
const [cache, setCache] = useState({});

if (cache[endpoint]) {
  return cache[endpoint];
}
```

3. Indexed queries en Firestore:
   - Firebase Console → Firestore → Indexes
   - Crear índices para campos que filtras

---

## 🟡 Almacenamiento Alto (Node.js Memory Leak)

**Síntoma:** Node.js usa cada vez más RAM

**Solución:**

En `server.js`, limpiar referencias:
```javascript
// Agregar al final de funciones largas
global.gc && global.gc();
```

O ejecutar Node con flag:
```bash
node --max-old-space-size=2048 server.js
```

---

## 📞 Reportar Bugs

Si el error persiste, incluir:

1. **Stack trace completo**
2. **Pasos para reproducir**
3. **Navegador/SO usado**
4. **Versiones:** Node, npm, React
5. **Logs:** DevTools + Node.js console

Ejemplo:
```
Error: Cannot read property 'id' of undefined
Pasos:
1. Click en Depósitos tab
2. Ver tabla vacía
3. Click en Aprobar

DevTools Console:
TypeError: Cannot read property 'id' of undefined
  at DepositosTab.jsx:45
  
Node.js logs:
[Error] GET /api/deposits returned null
```

---

## ✅ Checklist de Diagnóstico

Ante cualquier error:

- [ ] Backend corriendo: `npm start` en `admin/api/`
- [ ] Frontend corriendo: `npm run dev` en `admin/web/`
- [ ] `.env` configurado con `VITE_API_URL`
- [ ] `serviceAccountKey.json` presente en `admin/api/`
- [ ] Firestore tiene datos
- [ ] Usuario tiene rol `admin`
- [ ] Token no expirado (hacer login nuevo)
- [ ] Sin errores en DevTools console (F12)
- [ ] Sin errores en Node.js console

---

**Última actualización:** 2025  
**Versión:** 1.0

