# 💰 Caja de Ahorros App

Sistema completo de gestión de caja de ahorros con aplicación móvil Flutter y panel administrativo web.

## 📱 Descargar la App

### Para Usuarios Finales

👉 **[Descargar la última APK](https://github.com/cajaahorrofuturomejor2018-sudo/caja_ahorro_app/releases/latest)**

Instrucciones completas de instalación: **[DESCARGAR_APK.md](DESCARGAR_APK.md)**

---

## 🚀 Características

### 📱 Aplicación Móvil (Flutter)
- ✅ Registro de depósitos (ahorro mensual, plazos fijos, certificados)
- ✅ Solicitud de préstamos con cálculo automático de cuotas
- ✅ Sistema de multas con validaciones automáticas
- ✅ Dashboard con resumen de ahorros y préstamos
- ✅ Escaneo OCR de comprobantes de pago
- ✅ Upload de vouchers a Firebase Storage
- ✅ Notificaciones en tiempo real

### 🖥️ Panel Web Admin (React/Vite)
- ✅ Gestión de usuarios y roles
- ✅ Aprobación/rechazo de depósitos y préstamos
- ✅ Registro de pagos de préstamos
- ✅ Control de caja en tiempo real
- ✅ Auditoría completa de movimientos
- ✅ Reportes y estadísticas
- ✅ Upload obligatorio de contratos PDF

### 🔧 Backend (Node.js/Express + Firebase)
- ✅ API RESTful con autenticación JWT
- ✅ Firestore como base de datos
- ✅ Firebase Storage para archivos
- ✅ Validaciones de negocio automáticas
- ✅ Sistema de notificaciones
- ✅ Actualización automática de la caja

---

## 🏗️ Arquitectura

```
caja_ahorro_app/
├── lib/                    # App móvil Flutter
│   ├── screens/           # Pantallas de la app
│   ├── models/            # Modelos de datos
│   ├── core/services/     # Servicios (Firebase, OCR, etc.)
│   └── widgets/           # Componentes reutilizables
├── admin/                 # Panel administrativo
│   ├── api/              # Backend Node.js/Express
│   │   └── server.js     # API RESTful
│   └── web/              # Frontend React/Vite
│       └── src/pages/    # Páginas del panel
└── .github/workflows/    # CI/CD con GitHub Actions
    └── build-apk.yml     # Compilación automática de APK
```

---

## 🛠️ Tecnologías

### Mobile
- **Flutter 3.24.5** - Framework multiplataforma
- **Firebase** - Backend as a Service
  - Authentication
  - Firestore
  - Storage
  - Cloud Messaging

### Web Admin
- **React 18** - UI Framework
- **Vite** - Build tool
- **Axios** - HTTP Client
- **Docker** - Containerización

### Backend
- **Node.js 18** - Runtime
- **Express.js** - Web framework
- **Firebase Admin SDK** - Backend integration
- **Multer** - File uploads

---

## 📦 Instalación y Desarrollo

### Prerrequisitos
- Flutter 3.24.5 o superior
- Node.js 18 o superior
- Docker y Docker Compose
- Firebase project configurado

### 1. Clonar el repositorio
```bash
git clone https://github.com/cajaahorrofuturomejor2018-sudo/caja_ahorro_app.git
cd caja_ahorro_app
```

### 2. Configurar Firebase
1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com/)
2. Descarga `google-services.json` → `android/app/`
3. Descarga Service Account Key → `admin/api/serviceAccountKey.json`
4. Ejecuta: `flutterfire configure`

### 3. App Móvil Flutter

```bash
# Instalar dependencias
flutter pub get

# Ejecutar en emulador/dispositivo
flutter run

# Compilar APK
flutter build apk --release
```

### 4. Panel Web Admin (Docker)

```bash
cd admin

# Construir y levantar contenedores
docker compose up -d

# Ver logs
docker compose logs -f

# Acceder:
# - Web: http://localhost:5173
# - API: http://localhost:8080
```

### 5. Ejecutar Tests

```bash
# Tests Flutter
flutter test

# Tests completos
flutter test --coverage
```

---

## 🔐 Variables de Entorno

### Backend API (`admin/api/.env`)
```env
PORT=8080
SERVICE_ACCOUNT_PATH=/run/secrets/serviceAccountKey.json
ADMIN_EMAILS=admin@example.com
DISABLE_AUTH=false
MOCK_API=false
```

### Web Frontend (`admin/web/.env`)
```env
VITE_API_URL=http://localhost:8080
```

---

## 🚢 Despliegue

### Docker (Producción)
```bash
cd admin
docker compose -f docker-compose.yml up -d --build
```

### APK Release Automática
Cada push a `main` o `fix/deposito-reparto`:
1. Ejecuta tests
2. Compila APK release
3. Publica en GitHub Releases
4. Disponible para descargar automáticamente

---

## 📊 Flujo de Trabajo

### Usuario Móvil
1. Registra depósito con voucher
2. Sistema valida y detecta datos por OCR
3. Admin aprueba/rechaza desde panel web
4. Usuario recibe notificación
5. Saldo se actualiza automáticamente

### Admin Web
1. Revisa depósitos pendientes
2. Valida vouchers y documentos
3. Aprueba/rechaza con observaciones
4. Registra pagos de préstamos
5. Monitorea caja en tiempo real

---

## 🧪 Testing

```bash
# Tests unitarios
flutter test

# Tests con cobertura
flutter test --coverage

# Ver reporte de cobertura
genhtml coverage/lcov.info -o coverage/html
```

Todos los tests están pasando: ✅ **21/21**

---

## 📝 Funcionalidades Implementadas

### ✅ Depósitos
- Registro desde app móvil
- Validación de multas
- Aprobación admin con actualización de caja
- Soporte para reparto familiar

### ✅ Préstamos
- Solicitud con cálculo de cuotas
- Aprobación con contrato PDF obligatorio
- Registro de pagos
- Precancelación
- Historial completo

### ✅ Multas
- Cálculo automático por atrasos
- Bloqueo de depósitos si hay multas pendientes
- Pago dedicado con limpieza automática
- Integración con caja

### ✅ Caja
- Actualización automática en todos los movimientos
- Auditoría completa
- Control manual desde panel admin

---

## 🤝 Contribuir

1. Fork el proyecto
2. Crea tu rama (`git checkout -b feature/nueva-funcionalidad`)
3. Commit cambios (`git commit -m 'Añadir nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver [LICENSE](LICENSE) para más detalles.

---

## 👥 Autores

- **Caja de Ahorro Futuro Mejor 2018** - [cajaahorrofuturomejor2018-sudo](https://github.com/cajaahorrofuturomejor2018-sudo)

---

## 📞 Soporte

¿Problemas o preguntas? Abre un [Issue](https://github.com/cajaahorrofuturomejor2018-sudo/caja_ahorro_app/issues)

---

**Última actualización:** 13 de diciembre de 2025