# Panel de Administrador - Caja de Ahorros

Dashboard web completo para administración de la caja de ahorros. Incluye gestión de usuarios, depósitos, préstamos, familias, auditoría y reportes.

## 📋 Estructura

```
admin/
├── web/                      # Frontend React + Vite
│   ├── src/
│   │   ├── pages/           # Componentes de tabs
│   │   │   ├── Login.jsx
│   │   │   ├── Dashboard.jsx
│   │   │   ├── DepositosTab.jsx
│   │   │   ├── UsuariosTab.jsx
│   │   │   ├── PrestamosTab.jsx
│   │   │   ├── FamiliasTab.jsx
│   │   │   ├── CajaTab.jsx
│   │   │   ├── ReportesTab.jsx
│   │   │   ├── ConfiguracionTab.jsx
│   │   │   ├── AuditoriaTab.jsx
│   │   │   └── ValidacionesTab.jsx
│   │   ├── utils/
│   │   │   ├── apiClient.js  # Cliente HTTP centralizado
│   │   │   └── firebaseConfig.js
│   │   ├── styles.css
│   │   ├── main.jsx
│   │   └── App.jsx
│   ├── package.json
│   ├── vite.config.js
│   ├── .env.example
│   └── index.html
│
└── api/                       # Backend Express + Firebase Admin
    ├── server.js             # Servidor principal (802 líneas)
    └── package.json
```

## 🚀 Inicio Rápido

### Prerequisitos

- Node.js 18+
- npm o yarn
- Credenciales de Firebase Admin (serviceAccountKey.json)
- `.env` configurado con URL de API

### Configuración del Frontend

```bash
cd admin/web

# 1. Instalar dependencias
npm install

# 2. Configurar variables de entorno
cp .env.example .env

# Editar .env:
# VITE_API_URL=http://localhost:8080

# 3. Ejecutar en desarrollo
npm run dev

# El sitio estará en: http://localhost:5173
```

### Configuración del Backend

```bash
cd admin/api

# 1. Instalar dependencias
npm install

# 2. Configurar credenciales Firebase
# - Colocar serviceAccountKey.json en la raíz del proyecto
# - O configurar variable de entorno FIREBASE_CONFIG

# 3. Ejecutar en desarrollo
npm start

# El API estará en: http://localhost:8080
```

## 🔐 Autenticación

El sistema usa **Firebase Authentication** con email y contraseña.

### Roles Soportados

- **admin**: Acceso total a todas las funciones
- **gestor**: Gestión de depósitos y usuarios
- **cliente**: Acceso limitado a su propia información

### Login

```
Usuarios: Administrador de sistema
Contraseña: Configurada en Firebase Console
URL: http://localhost:5173/login
```

## 📱 Funcionalidades por Tab

### 1. **Usuarios** 
Gestión completa de usuarios del sistema

- ✅ Listar todos los usuarios
- ✅ Crear nuevos usuarios
- ✅ Cambiar rol (cliente → admin → gestor)
- ✅ Cambiar estado (activo → inactivo)
- ✅ Copiar UID para referencias

### 2. **Depósitos**
Administración de depósitos y aportes

- ✅ Listar depósitos pendientes y aprobados
- ✅ Aprobar o rechazar depósitos
- ✅ Crear depósitos manuales
- ✅ Calcular penalizaciones automáticamente
- ✅ Vincular con lógica de multas

**Lógica de Penalizaciones:**
- Día límite: 10 de cada mes
- Desde día 11: S/ 1.00/semana (Ahorro)
- Préstamos: 7% días 1-15, 10% días 16-30, acumula después

### 3. **Préstamos**
Control de solicitudes de crédito

- ✅ Listar préstamos pendientes
- ✅ Aprobar o rechazar
- ✅ Ver monto solicitado
- ✅ Registrar estado

### 4. **Familias**
Organización de grupos de usuarios

- ✅ Crear nuevas familias
- ✅ Listar familias existentes
- ✅ Asociar usuarios a familias

### 5. **Caja**
Control del saldo total

- ✅ Ver saldo actual en tiempo real
- ✅ Actualizar saldo manual (auditoría)
- ✅ Mostrar en formato moneda

### 6. **Reportes**
Análisis agregado y exportación

- ✅ Total depósitos
- ✅ Total préstamos
- ✅ Total aportes extras
- ✅ Total retirado
- ✅ Descargar como JSON
- ✅ Descargar como CSV

### 7. **Configuración**
Parámetros del sistema

- ✅ Enlace WhatsApp del grupo
- ✅ Correo de soporte
- ✅ Teléfono de contacto
- ✅ Descripción de la organización

### 8. **Auditoría**
Registro completo de movimientos

- ✅ Fecha y hora de cada operación
- ✅ Tipo de movimiento
- ✅ Usuario responsable
- ✅ Monto e importancia
- ✅ Descripción de la acción

### 9. **Validaciones**
Aprobación manual de depósitos pendientes

- ✅ Ver depósitos sin validar
- ✅ Revisar detalle completo
- ✅ Distribuir entre usuarios (modo manual)
- ✅ Vista previa de distribución
- ✅ Aprobar con auto-distribución o manual

## 🔌 API Endpoints

### Autenticación
- `POST /api/login` - Obtener token (Firebase)

### Depósitos
- `GET /api/deposits` - Listar todos
- `GET /api/deposits/pending` - Pendientes de validación
- `POST /api/deposits/:id/approve` - Aprobar/rechazar

### Usuarios
- `GET /api/users` - Listar usuarios
- `POST /api/users` - Crear usuario
- `POST /api/users/:uid/role` - Cambiar rol
- `POST /api/users/:uid/estado` - Cambiar estado

### Caja
- `GET /api/caja` - Obtener saldo
- `POST /api/caja` - Actualizar saldo

### Otros
- `GET /api/config` - Obtener configuración
- `POST /api/config` - Guardar configuración
- `GET /api/familias` - Listar familias
- `POST /api/familias` - Crear familia
- `GET /api/movimientos` - Log de auditoría
- `GET /api/aggregate_totals` - Totales agregados
- `POST /api/aportes` - Crear aporte

## 🎨 Diseño UI

### Componentes
- **Alerts**: Success (verde), Error (rojo), Info (azul), Warning (naranja)
- **Tablas**: Striped, hover effects, responsive
- **Formularios**: Validación de campos, inputs con estilos
- **Modales**: Overlay, centrado, con cerrar
- **Buttons**: Primary (azul), Secondary (gris), Danger (rojo), Success (verde)

### Responsive
- Desktop: Full layout
- Tablet (768px): Redimensionamiento de grid
- Mobile (480px): Stack vertical, fonts pequeños

### Colores
- Primary: #1976d2 (Azul)
- Secondary: #388e3c (Verde)
- Danger: #d32f2f (Rojo)
- Warning: #f57c00 (Naranja)
- Success: #388e3c (Verde)

## 🛠️ Desarrollo

### Cliente API Centralizado

Archivo: `src/utils/apiClient.js`

```javascript
import { 
  setAuthToken,
  fetchDeposits, 
  approveDeposit,
  fetchUsers,
  createUser,
  fetchCaja,
  updateCaja,
  // ... más funciones
} from './utils/apiClient.js';

// Usar en componentes
async function load() {
  const result = await fetchDeposits();
  if (result.success) {
    setDeposits(result.data);
  } else {
    setError(result.error);
  }
}
```

### Estructura de Respuesta

```javascript
{
  success: true,
  data: {...}
}

// O error:
{
  success: false,
  error: "Mensaje de error"
}
```

### Estados de Depósito
- `pendiente` - Esperando validación
- `aprobado` - Procesado correctamente
- `rechazado` - No aprobado

### Estados de Usuario
- `activo` - Puede usar la app
- `inactivo` - Acceso restringido

## 📊 Flujo de Depósito

1. Usuario sube depósito en app
2. Sistema registra en estado `pendiente`
3. Admin ve en **Validaciones**
4. Admin revisa detalle y:
   - **Rechaza**: Depósito se cancela
   - **Aprueba (Auto)**: Distribuye según lógica
   - **Aprueba (Manual)**: Distribuye a usuarios seleccionados
5. Sistema calcula penalizaciones si procede
6. Actualiza saldos en Firestore
7. Registra en auditoría

## 🔍 Troubleshooting

### "Error conectando a API"
```
✅ Verificar que backend está corriendo (port 8080)
✅ Verificar .env tiene VITE_API_URL correcto
✅ Revisar consola del navegador (F12)
```

### "No autorizado / 401"
```
✅ Token expirado: Hacer login de nuevo
✅ Rol insuficiente: Verificar permisos en Firebase
```

### "Depósito no se distribuye correctamente"
```
✅ Revisar lógica en server.js líneas 360-600
✅ Verificar penalizaciones en firestore_service.dart
✅ Chequear consola de Node.js para errores
```

### "Base de datos desactualizada"
```
✅ Click en botón "Actualizar" de cada tab
✅ Refrescar página (Ctrl+F5)
✅ Verificar Firestore en Firebase Console
```

## 📚 Recursos

- [Firebase Console](https://console.firebase.google.com)
- [React Documentation](https://react.dev)
- [Vite Documentation](https://vitejs.dev)
- [Express Documentation](https://expressjs.com)

## 📝 Notas

- Todas las operaciones se registran en auditoría
- Los cambios se sincronizan en tiempo real con Firestore
- El sistema maneja concurrencia con transacciones
- Las penalizaciones se calculan automáticamente

## ✅ Checklist Implementación

- [x] Frontend React con 9 tabs
- [x] Cliente HTTP centralizado (apiClient.js)
- [x] Diseño responsivo (CSS completo)
- [x] Autenticación Firebase
- [x] Gestión de usuarios y roles
- [x] Depósitos y aprobaciones
- [x] Cálculo de penalizaciones
- [x] Auditoría y reportes
- [x] Validación de datos
- [x] Manejo de errores
- [x] Estados de carga (loading)
- [x] Confirmaciones de acciones

## 🚢 Deployment

Ver `docker-compose.yml` para containerización:

```bash
cd admin
docker-compose up -d
```

Esto levanta:
- Frontend en puerto 5173 (acceso público)
- Backend API en puerto 8080 (interno)
- Nginx reverse proxy si se configura

---

**Última actualización:** 2025
**Versión:** 1.0
**Autor:** Sistema Administrativo

