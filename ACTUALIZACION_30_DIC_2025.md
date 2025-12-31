# 🔄 Actualización 30 Diciembre 2025

## ✅ Correcciones Implementadas

### 1. 📱 App Móvil: Campo Ahorro Voluntario
**Problema**: El campo de ahorro voluntario no se mostraba correctamente en la aplicación móvil.

**Solución**:
- Agregado campo `totalAhorroVoluntario` al modelo `Usuario` ([lib/models/usuario.dart](lib/models/usuario.dart))
- Actualizado `cliente_dashboard.dart` para mostrar el total acumulado desde Firestore
- Actualizado `firestore_service.dart` para mapear correctamente `ahorro_voluntario` → `total_ahorro_voluntario`

**Archivos modificados**:
- `lib/models/usuario.dart`: Líneas 15, 36, 73
- `lib/screens/cliente/cliente_dashboard.dart`: Línea 509
- `lib/core/services/firestore_service.dart`: Línea 21

### 2. 📄 Web Admin: Generación de PDFs
**Problema**: Los PDFs no se generaban correctamente en el panel web de administración.

**Estado**: ✅ **VERIFICADO** - El endpoint `/api/reportes/usuarios` genera correctamente PDFs de 12KB+

**Prueba realizada**:
```powershell
Invoke-WebRequest -Uri "http://localhost:8080/api/reportes/usuarios" `
  -Headers @{"Authorization"="Bearer test"} `
  -OutFile "test_reporte.pdf"
# Resultado: 12,832 bytes - PDF válido
```

## 🐳 Imágenes Docker Actualizadas

Las imágenes fueron reconstruidas y subidas a Docker Hub:

### API (Backend)
```
cajawebapk/caja-admin-api:latest
Digest: sha256:86001bb3361cf8e3de83a9abea51d198f0095bb8fec0611afbf63b16e7d09c24
```

### Web (Frontend)
```
cajawebapk/caja-admin-web:latest
Digest: sha256:cf577bbee7a6090d330e0aaedb20bb4e1e3cbe51988cc519b037ffde1b472e80
```

## 📦 APK Android

**Ubicación**: `release_apk/app-release-v1.0.1-30dic2025.apk`

**Cambios incluidos**:
- ✅ Lectura correcta de `total_ahorro_voluntario` desde Firestore
- ✅ Actualización automática de totales en el dashboard del cliente
- ✅ Soporte completo para tipo de depósito `ahorro_voluntario`

## 🚀 Instrucciones de Actualización

### En Otra Máquina (Con Docker)

1. **Descargar imágenes actualizadas**:
```powershell
docker pull cajawebapk/caja-admin-api:latest
docker pull cajawebapk/caja-admin-web:latest
```

2. **Reiniciar servicios** (desde la carpeta del proyecto):
```powershell
cd C:\ruta\a\caja_ahorro_app
docker compose -f admin\docker-compose.prod.yml down
docker compose -f admin\docker-compose.prod.yml up -d
```

3. **Verificar**:
```powershell
docker compose -f admin\docker-compose.prod.yml ps
docker logs caja_admin_api --tail 30
docker logs caja_admin_web --tail 30
```

4. **Acceder**:
- Web Admin: http://localhost:5173
- API: http://localhost:8080

### Instalación del APK en Móviles

1. Copiar `release_apk/app-release-v1.0.1-30dic2025.apk` al dispositivo
2. Habilitar "Instalar aplicaciones desconocidas" (si es necesario)
3. Abrir el APK y seguir las instrucciones de instalación
4. Iniciar sesión con las credenciales de Firebase Auth

## 🔍 Verificación de Funcionamiento

### Backend (API)
```powershell
# Probar endpoint de reportes PDF
Invoke-WebRequest -Uri "http://localhost:8080/api/reportes/usuarios" `
  -Headers @{"Authorization"="Bearer test"} `
  -OutFile "reporte_test.pdf"

# Verificar saldo de caja (debe incluir total_ahorro_voluntario)
Invoke-WebRequest -Uri "http://localhost:8080/api/caja" `
  -Headers @{"Authorization"="Bearer test"} | 
  Select-Object -ExpandProperty Content | ConvertFrom-Json
```

### App Móvil
1. Iniciar sesión como usuario cliente
2. Verificar que el dashboard muestre correctamente:
   - Ahorro Mensual
   - Ahorro Voluntario ✅ **CORREGIDO**
   - Plazos Fijos
   - Certificados
3. Crear un depósito de tipo "Ahorro voluntario"
4. Verificar que el total se actualice correctamente después de la aprobación por admin

### Web Admin
1. Acceder a http://localhost:5173
2. Ir a la sección de "Reportes"
3. Click en "📄 Exportar Reporte PDF"
4. Verificar que el PDF se descargue correctamente ✅ **VERIFICADO**

## 📝 Notas Técnicas

- La migración de `ahorro_voluntario` → `total_ahorro_voluntario` ya fue ejecutada en el backend
- El modelo `Usuario` ahora incluye el campo `totalAhorroVoluntario: 0.0` por defecto
- Los depósitos de tipo `ahorro_voluntario` actualizan correctamente el campo en Firestore
- El endpoint PDF usa `pdfmake` con fuentes estándar (Helvetica, Courier, Times)

## 🆕 Próximos Pasos (Opcional)

Si deseas actualizar las dependencias de Flutter (43 paquetes tienen versiones más nuevas):
```bash
flutter pub outdated
flutter pub upgrade
```

---

**Fecha de actualización**: 30 de diciembre de 2025  
**Versión**: v1.0.1  
**Commit**: Corrección de ahorro voluntario y PDFs
