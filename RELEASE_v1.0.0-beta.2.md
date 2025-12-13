# Caja de Ahorro - v1.0.0-beta.2

## Mejoras principales
- ✅ **Multas por día de atraso**: Cálculo correcto basado en días transcurridos desde fecha límite hasta fecha de pago
  - Soporta `penalty.type`: `per_day_fixed` (monto fijo por día) y `per_day_percent` (% del monto por día)
- ✅ **Separación correcta de montos**: Depósitos tipo 'multa' se envían directamente a caja, no a totales de usuario
- ✅ **Admin UI mejorada**: 
  - CajaTab con saldo automático de solo lectura
  - Modal de aprobación en DepositosTab con interés % y PDF para plazos fijos/certificados
  - Visor de vouchers inline en tabla de depósitos
- ✅ **Reportes PDF**: Generación de reportes de usuarios con pdfmake

## Docker Images Publicadas
Las imágenes Docker están disponibles en Docker Hub:

```bash
# Descargar imagen de la API
docker pull rjacebo956/caja-ahorro-api:latest

# Descargar imagen del Web Admin
docker pull rjacebo956/caja-ahorro-web:latest

# Ejecutar con Docker Compose (en carpeta admin/)
docker-compose up -d
```

## Instalación APK (Android)
1. Descarga el archivo `app-release.apk` desde GitHub Releases
2. En tu dispositivo Android, ve a **Configuración → Seguridad**
3. Activa **Permitir instalación desde fuentes desconocidas**
4. Abre el archivo APK descargado e instala

## Ubicación del APK compilado
El APK está en: `build\app\outputs\flutter-apk\app-release.apk` (91.9MB)

## Cambios en el código
### Backend (`admin/api/server.js`)
- **computePenalty()**: Cálculo por días de atraso desde la fecha límite (con gracia) hasta la fecha del voucher
- **Aprobación de depósitos con detalle**: Montos con `tipo: "multa"` se acumulan y envían solo a `caja/estado.saldo`

### Frontend (`admin/web/`)
- **CajaTab.jsx**: UI rediseñada con tarjeta de saldo, ingresos/egresos, tabla de transacciones
- **DepositosTab.jsx**: Modal de aprobación con campos de interés % y carga de PDF
- **Dockerfile**: Instalación de devDependencies y ejecución directa de Vite

## Repositorio
https://github.com/cajaahorrofuturomejor2018-sudo/caja_ahorro_app

## Commit
Tag: `v1.0.0-beta.2`
Commit: `7af4584`
