# Testing de Endpoints - API de Administrador

Guía completa para probar todos los endpoints del backend.

## 🛠️ Herramientas Recomendadas

- **Postman** (GUI)
- **cURL** (Terminal)
- **Thunder Client** (VS Code Extension)
- **REST Client** (VS Code Extension)

## 📋 Base de Conocimiento

**URL Base:** `http://localhost:8080`  
**Header de Autenticación:**
```
Authorization: Bearer {ID_TOKEN_FIREBASE}
```

## 🔐 Obtener Token de Prueba

### Opción 1: Desde el Dashboard
1. Abrir el navegador en `http://localhost:5173`
2. Login con admin/contraseña
3. Abrir DevTools (F12)
4. Console: `console.log(localStorage.getItem('user-token'))`
5. Copiar el token

### Opción 2: Desde Node.js
```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const uid = 'user-uid-aqui';
admin.auth().createCustomToken(uid).then(token => {
  console.log('Token:', token);
}).catch(err => console.error(err));
```

### Opción 3: Modo MOCK (Desarrollo)
En `server.js` línea ~50:
```javascript
const MOCK_API = true; // Activa modo sin Firebase
```

## 📝 Colección de Endpoints

### 1. USUARIOS
---

#### GET /api/users - Listar usuarios

```bash
curl -X GET http://localhost:8080/api/users \
  -H "Authorization: Bearer TOKEN_AQUI"
```

**Respuesta Esperada:**
```json
[
  {
    "id": "user123",
    "nombres": "Juan García",
    "correo": "juan@example.com",
    "rol": "cliente",
    "estado": "activo",
    "telefono": "+51900000001"
  }
]
```

#### POST /api/users - Crear usuario

```bash
curl -X POST http://localhost:8080/api/users \
  -H "Authorization: Bearer TOKEN_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "nombre": "Carlos López",
    "correo": "carlos@example.com",
    "password": "contraseña123",
    "rol": "cliente",
    "telefono": "+51900000002",
    "direccion": "Calle Principal 123"
  }'
```

**Respuesta Esperada:**
```json
{
  "uid": "new-user-id-generated",
  "email": "carlos@example.com",
  "message": "Usuario creado exitosamente"
}
```

#### POST /api/users/{uid}/role - Cambiar rol

```bash
curl -X POST http://localhost:8080/api/users/user123/role \
  -H "Authorization: Bearer TOKEN_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "role": "admin"
  }'
```

**Roles válidos:** `cliente`, `admin`, `gestor`

#### POST /api/users/{uid}/estado - Cambiar estado

```bash
curl -X POST http://localhost:8080/api/users/user123/estado \
  -H "Authorization: Bearer TOKEN_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "estado": "inactivo"
  }'
```

**Estados válidos:** `activo`, `inactivo`

---

### 2. DEPÓSITOS
---

#### GET /api/deposits - Listar depósitos

```bash
curl -X GET http://localhost:8080/api/deposits \
  -H "Authorization: Bearer TOKEN_AQUI"
```

**Respuesta Esperada:**
```json
[
  {
    "id": "deposit123",
    "id_usuario": "user123",
    "monto": 100.00,
    "tipo": "aporte",
    "estado": "pendiente",
    "fecha_deposito": "2025-01-15T10:30:00Z",
    "descripcion": "Aporte mensual"
  }
]
```

#### GET /api/deposits/pending - Depósitos pendientes

```bash
curl -X GET http://localhost:8080/api/deposits/pending \
  -H "Authorization: Bearer TOKEN_AQUI"
```

#### POST /api/deposits/{id}/approve - Aprobar depósito

```bash
curl -X POST http://localhost:8080/api/deposits/deposit123/approve \
  -H "Authorization: Bearer TOKEN_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "approve": true,
    "observaciones": "Aprobado por validación manual"
  }'
```

**Parámetros:**
- `approve` (boolean): true para aprobar, false para rechazar
- `observaciones` (string, opcional): Comentario del administrador
- `detalleOverride` (array, opcional): Para distribución manual

**Respuesta Esperada:**
```json
{
  "success": true,
  "message": "Depósito aprobado",
  "deposit": {...},
  "penalties_applied": [
    {
      "user": "user456",
      "penalty": 1.00,
      "reason": "Retraso 1+ semanas"
    }
  ]
}
```

#### POST /api/aportes - Crear aporte

```bash
curl -X POST http://localhost:8080/api/aportes \
  -H "Authorization: Bearer TOKEN_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "idUsuario": "user123",
    "tipo": "aporte",
    "monto": 50.00,
    "descripcion": "Aporte adicional manual"
  }'
```

**Tipos válidos:** `aporte`, `aporte_extra`, `certificado`, `retiro`

---

### 3. CAJA
---

#### GET /api/caja - Obtener saldo

```bash
curl -X GET http://localhost:8080/api/caja \
  -H "Authorization: Bearer TOKEN_AQUI"
```

**Respuesta Esperada:**
```json
{
  "saldo": 5000.00,
  "last_updated": "2025-01-15T10:30:00Z"
}
```

#### POST /api/caja - Actualizar saldo

```bash
curl -X POST http://localhost:8080/api/caja \
  -H "Authorization: Bearer TOKEN_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "saldo": 5500.00
  }'
```

---

### 4. FAMILIAS
---

#### GET /api/familias - Listar familias

```bash
curl -X GET http://localhost:8080/api/familias \
  -H "Authorization: Bearer TOKEN_AQUI"
```

#### POST /api/familias - Crear familia

```bash
curl -X POST http://localhost:8080/api/familias \
  -H "Authorization: Bearer TOKEN_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "nombre": "Familia García López"
  }'
```

---

### 5. CONFIGURACIÓN
---

#### GET /api/config - Obtener configuración

```bash
curl -X GET http://localhost:8080/api/config \
  -H "Authorization: Bearer TOKEN_AQUI"
```

#### POST /api/config - Actualizar configuración

```bash
curl -X POST http://localhost:8080/api/config \
  -H "Authorization: Bearer TOKEN_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "whatsapp_link": "https://chat.whatsapp.com/...",
    "support_email": "soporte@example.com",
    "support_phone": "+51900000000",
    "org_description": "Caja de Ahorros Comunitaria"
  }'
```

---

### 6. AUDITORÍA
---

#### GET /api/movimientos - Obtener movimientos

```bash
curl -X GET http://localhost:8080/api/movimientos \
  -H "Authorization: Bearer TOKEN_AQUI"
```

**Respuesta Esperada:**
```json
[
  {
    "id": "mov123",
    "fecha": {"seconds": 1705315800},
    "tipo": "deposito_aprobado",
    "id_usuario": "user123",
    "monto": 100.00,
    "descripcion": "Depósito aprobado por admin"
  }
]
```

---

### 7. REPORTES
---

#### GET /api/aggregate_totals - Totales agregados

```bash
curl -X GET http://localhost:8080/api/aggregate_totals \
  -H "Authorization: Bearer TOKEN_AQUI"
```

**Respuesta Esperada:**
```json
{
  "total_depositos": 1000.00,
  "total_prestamos": 500.00,
  "total_aportes_extras": 250.00,
  "total_retirado": 100.00,
  "usuarios_activos": 25,
  "num_familias": 5
}
```

---

## ✅ Checklist de Pruebas

### Usuarios
- [ ] GET /api/users - Listar
- [ ] POST /api/users - Crear
- [ ] POST /api/users/{uid}/role - Cambiar rol
- [ ] POST /api/users/{uid}/estado - Cambiar estado

### Depósitos
- [ ] GET /api/deposits - Listar todos
- [ ] GET /api/deposits/pending - Ver pendientes
- [ ] POST /api/deposits/{id}/approve - Aprobar (true)
- [ ] POST /api/deposits/{id}/approve - Rechazar (false)
- [ ] POST /api/aportes - Crear aporte

### Caja
- [ ] GET /api/caja - Ver saldo
- [ ] POST /api/caja - Actualizar saldo

### Familias
- [ ] GET /api/familias - Listar
- [ ] POST /api/familias - Crear

### Configuración
- [ ] GET /api/config - Obtener
- [ ] POST /api/config - Actualizar

### Auditoría
- [ ] GET /api/movimientos - Obtener log

### Reportes
- [ ] GET /api/aggregate_totals - Totales

---

## 🐛 Códigos de Error Comunes

| Código | Significado | Solución |
|--------|------------|----------|
| 400 | Bad Request | Validar JSON, campos requeridos |
| 401 | Unauthorized | Token inválido o expirado, hacer login |
| 403 | Forbidden | Rol insuficiente (requiere admin) |
| 404 | Not Found | Recurso no existe |
| 500 | Server Error | Error en backend, revisar logs Node.js |

---

## 📊 Escenarios de Prueba

### Escenario 1: Flujo Completo de Depósito

1. ✅ Crear usuario: `POST /api/users`
2. ✅ Ver saldo caja actual: `GET /api/caja`
3. ✅ Crear aporte: `POST /api/aportes`
4. ✅ Listar pendientes: `GET /api/deposits/pending`
5. ✅ Aprobar: `POST /api/deposits/{id}/approve` con `approve: true`
6. ✅ Verificar auditoría: `GET /api/movimientos`
7. ✅ Verificar saldo actualizado: `GET /api/caja`

### Escenario 2: Gestión de Usuarios

1. ✅ Crear usuario: `POST /api/users`
2. ✅ Cambiar rol a admin: `POST /api/users/{uid}/role` con `role: "admin"`
3. ✅ Listar y verificar: `GET /api/users`
4. ✅ Inactivar: `POST /api/users/{uid}/estado` con `estado: "inactivo"`
5. ✅ Verificar cambio: `GET /api/users`

### Escenario 3: Reportes

1. ✅ Obtener totales: `GET /api/aggregate_totals`
2. ✅ Obtener log: `GET /api/movimientos`
3. ✅ Obtener config: `GET /api/config`

---

## 🔧 Debugging

### Ver Logs del Backend

```bash
cd admin/api
npm start

# Verás en consola:
# ✅ Firebase Admin SDK inicializado
# ✅ Token verificado: user@example.com
# GET /api/deposits - 200 OK
# POST /api/deposits/:id/approve - 200 OK
```

### Verificar Firestore

1. Abrir [Firebase Console](https://console.firebase.google.com)
2. Navegar a Firestore Database
3. Ver colecciones: `users`, `deposits`, `caja`, `movimientos`
4. Verificar que los datos se actualicen en tiempo real

### Monitorear Requests en DevTools

1. Abrir navegador en dashboard
2. F12 → Network tab
3. Realizar acciones
4. Ver requests HTTP con status codes

---

## 📖 Referencias

- [cURL Manual](https://curl.se/docs/manual.html)
- [REST API Best Practices](https://restfulapi.net)
- [HTTP Status Codes](https://httpstat.us)
- [Firebase Documentation](https://firebase.google.com/docs)

---

**Última actualización:** 2025  
**Versión:** 1.0

