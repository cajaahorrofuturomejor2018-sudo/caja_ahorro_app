# 🚀 Guía de Deployment - Caja de Ahorros

## 📦 Contenido

Este repositorio contiene el sistema completo de Caja de Ahorros con:
- **App Móvil**: Flutter (Android/iOS)
- **Panel Admin Web**: React + Vite
- **API Backend**: Node.js + Express
- **Base de Datos**: Firebase Firestore

## 🐳 Docker Hub - Imágenes Disponibles

Las imágenes Docker están disponibles en Docker Hub para deployment rápido:

```bash
# Admin API
docker pull rjacebo956/caja-ahorro-admin-api:latest

# Admin Web
docker pull rjacebo956/caja-ahorro-admin-web:latest
```

## 🔧 Deployment con Docker

### Paso 1: Clonar el repositorio

```bash
git clone https://github.com/cajaahorrofuturomejor2018-sudo/caja_ahorro_app.git
cd caja_ahorro_app/admin
```

### Paso 2: Configurar Firebase

Coloca tu archivo `serviceAccountKey.json` en `admin/api/`:

```bash
# Debe existir:
admin/api/serviceAccountKey.json
```

### Paso 3: Iniciar servicios con Docker Compose

```bash
cd admin
docker-compose up -d
```

Esto levanta:
- **Admin API**: http://localhost:8080
- **Admin Web**: http://localhost:5173

### Paso 4: Verificar servicios

```bash
docker-compose ps
docker-compose logs -f
```

## 📱 Build de la APK (Android)

### Requisitos:
- Flutter SDK instalado
- Java JDK 21 configurado
- Android SDK

### Build:

```bash
# Desde la raíz del proyecto
flutter build apk --release

# APK generado en:
build/app/outputs/flutter-apk/app-release.apk
```

## 🌐 Deployment Web (GitHub Pages / Netlify / Vercel)

### Build del frontend web:

```bash
cd admin/web
npm install
npm run build

# Archivos generados en:
admin/web/dist/
```

## 🔑 Variables de Entorno

### Admin API (admin/api)

Configuradas en `docker-compose.yml`:

```yaml
environment:
  - SERVICE_ACCOUNT_PATH=/run/secrets/serviceAccountKey.json
  - MOCK_API=false
  - DISABLE_AUTH=true
  - ADMIN_EMAILS=cajaahorrofuturomejor2018@gmail.com
```

### Admin Web (admin/web)

Configuradas en build args:

```yaml
args:
  - VITE_API_URL=/api
```

## 🧪 Tests

### Tests Unitarios

```bash
# Auto-reparto mensual (8 tests)
node scripts/test_auto_reparto.js

# Tests extremos del sistema (21 tests)
node scripts/test_extremo_sistema.js
```

### Resultados esperados:

```
✅ Tests Pasados: 21
❌ Tests Fallidos: 0
📈 Total de Tests: 21
🎯 Tasa de Éxito: 100.00%
```

## 📊 Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                    USUARIOS FINALES                      │
├────────────────┬──────────────────┬─────────────────────┤
│   App Móvil    │   Panel Admin    │   API REST          │
│   (Flutter)    │   (React+Vite)   │   (Node.js)         │
├────────────────┴──────────────────┴─────────────────────┤
│                                                           │
│              Firebase Firestore (Database)               │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

## 🔄 Actualización de Imágenes Docker

Cuando hagas cambios en el código:

### 1. Rebuild local:

```bash
cd admin
docker-compose build --no-cache
docker-compose up -d
```

### 2. Push a Docker Hub:

```bash
# Primero, login en Docker Hub
docker login

# Ejecutar script de push
.\scripts\push-docker-hub.ps1 -DockerHubUsername "rjacebo956"
```

### 3. Pull en servidor de producción:

```bash
docker pull rjacebo956/caja-ahorro-admin-api:latest
docker pull rjacebo956/caja-ahorro-admin-web:latest

docker-compose down
docker-compose up -d
```

## 📋 Puertos Utilizados

| Servicio      | Puerto Local | Puerto Docker |
|---------------|--------------|---------------|
| Admin API     | 8080         | 8080          |
| Admin Web     | 5173         | 80            |

## 🛠️ Solución de Problemas

### El contenedor del API no inicia:

```bash
# Ver logs
docker logs caja_admin_api --tail 50

# Verificar que existe serviceAccountKey.json
ls admin/api/serviceAccountKey.json
```

### El contenedor web no puede conectar al API:

Verificar `nginx.conf`:

```nginx
location /api/ {
    proxy_pass http://api:8080/;
}
```

### Puerto 8080 ya en uso:

Cambiar en `docker-compose.yml`:

```yaml
ports:
  - "9000:8080"  # Usar puerto 9000 en lugar de 8080
```

## 📚 Documentación Adicional

- [Auto-Reparto Mensual](../docs/AUTO_REPARTO_MENSUAL.md)
- [Upgrade JDK 21](../JAVA21_UPGRADE.md)
- [Setup Nativo](../docs/setup_native.md)
- [Firebase Rules](../FIREBASE_RULES_README.md)

## 🆕 Últimas Funcionalidades

### Auto-Reparto Mensual (v1.0.0)

Sistema automático que divide depósitos en cuotas mensuales de $25:

- ✅ Depósito de $75 → 3 meses (enero, febrero, marzo)
- ✅ Evita penalizaciones incorrectas
- ✅ 100% testeado (21 casos extremos)
- ✅ Maneja años bisiestos y cruces de año
- ✅ Rendimiento: 1000 depósitos en 1ms

### Reportes PDF Mejorados

- ✅ Tablas con formato profesional
- ✅ Emojis en headers
- ✅ Nombres de usuarios (no IDs)
- ✅ Totales y resúmenes
- ✅ Exportación desde ReportesTab

## 🔒 Seguridad

### Autenticación:

Actualmente configurado con `DISABLE_AUTH=true` para desarrollo.

**Para producción**, cambiar a:

```yaml
environment:
  - DISABLE_AUTH=false
```

Y configurar Firebase Auth correctamente.

### Firestore Rules:

Las reglas de seguridad están en:
- `firestore.rules`
- Ver documentación en `FIREBASE_RULES_README.md`

## 📞 Soporte

Para issues y preguntas:
- GitHub Issues: https://github.com/cajaahorrofuturomejor2018-sudo/caja_ahorro_app/issues
- Email: cajaahorrofuturomejor2018@gmail.com

## 📄 Licencia

[Especificar licencia aquí]

---

**Última actualización**: Diciembre 2025  
**Versión**: 1.0.0  
**Estado**: ✅ Producción Ready
