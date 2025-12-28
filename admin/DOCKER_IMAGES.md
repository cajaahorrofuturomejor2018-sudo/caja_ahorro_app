# Docker Images - Versiones Sincronizadas

## Última Actualización
**Fecha:** 28 de diciembre de 2025  
**Commit:** `aba6606` - fix(nginx): resolver DNS dinámico compatible

## Imágenes en Docker Hub (cajawebapk namespace)

### API
- **Imagen:** `cajawebapk/caja-admin-api:latest`
- **Digest:** `sha256:d314e47127639f44ecd92f41d71c8de1c44f9a2c289e242f1dddec9d0412b8d2`
- **Cambios incluidos:**
  - ✅ Saldo dinámico basado en totales de usuarios
  - ✅ Desglose de ahorros, certificados, plazos, préstamos, multas
  - ✅ Endpoint `/api/caja` retorna detalle completo

### Web (Nginx + React)
- **Imagen:** `cajawebapk/caja-admin-web:latest`
- **Digest:** `sha256:a3d3bf0594f1aea9468d7bc335a65b5b07f3cd632b6efe69e410dcd02588df3f`
- **Cambios incluidos:**
  - ✅ Resolver DNS dinámico compatible con Windows/Linux/WSL
  - ✅ Proxy de API funcional en cualquier entorno Docker
  - ✅ Variables dinámicas en lugar de upstream blocks

## Instrucciones para Actualizar en Otra Máquina

### Opción 1: Comando Rápido (Una sola línea)
```powershell
cd tu_ruta\caja_ahorro_app\admin; git pull origin main; docker pull cajawebapk/caja-admin-api:latest; docker pull cajawebapk/caja-admin-web:latest; docker-compose down; docker-compose up -d; docker-compose ps
```

### Opción 2: Paso a Paso
```powershell
# 1. Actualizar código
cd tu_ruta\caja_ahorro_app\admin
git pull origin main

# 2. Descargar imágenes
docker pull cajawebapk/caja-admin-api:latest
docker pull cajawebapk/caja-admin-web:latest

# 3. Reiniciar servicios
docker-compose down
docker-compose up -d

# 4. Verificar
docker-compose ps
docker logs caja_admin_web --tail 20
docker logs caja_admin_api --tail 20
```

### Opción 3: Script PowerShell (Guardar como `update.ps1`)
```powershell
Write-Host "=== Actualizando Caja de Ahorros Admin ===" -ForegroundColor Green
Write-Host ""

# Cambiar a directorio
$adminDir = "tu_ruta\caja_ahorro_app\admin"
if (-Not (Test-Path $adminDir)) {
    Write-Host "❌ Directorio no encontrado: $adminDir" -ForegroundColor Red
    exit 1
}
cd $adminDir

# Actualizar código
Write-Host "📥 Descargando cambios de GitHub..." -ForegroundColor Cyan
git pull origin main

# Descargar imágenes
Write-Host "🐳 Descargando imágenes de Docker Hub..." -ForegroundColor Cyan
docker pull cajawebapk/caja-admin-api:latest
docker pull cajawebapk/caja-admin-web:latest

# Reiniciar
Write-Host "🔄 Deteniendo contenedores..." -ForegroundColor Cyan
docker-compose down

Write-Host "🚀 Iniciando nuevos contenedores..." -ForegroundColor Cyan
docker-compose up -d

# Verificar
Write-Host "✅ Estado de servicios:" -ForegroundColor Green
docker-compose ps

Write-Host ""
Write-Host "✅ ¡Actualización completada!" -ForegroundColor Green
Write-Host "📍 Acceder en: http://localhost" -ForegroundColor Yellow
```

## Verificación Rápida

```powershell
# Probar API
curl -H "Authorization: Bearer test" http://localhost:8080/api/caja

# Ver saldo actualizado
# Debería mostrar algo como:
# {
#   "saldo": 1173,
#   "saldo_almacenado": 100,
#   "detalle": {
#     "total_ahorros": 1090,
#     "total_certificados": 80,
#     ...
#   }
# }
```

## Cambios Importantes en Esta Versión

| Cambio | API | Web | Impacto |
|--------|-----|-----|---------|
| Saldo dinámico desde usuarios | ✅ | — | Refleja inmediatamente valores registrados |
| Resolver DNS compatible | — | ✅ | Funciona en cualquier máquina |
| Endpoint /api/caja mejorado | ✅ | — | Retorna desglose completo |

## Troubleshooting

Si algo falla:

```powershell
# Ver logs detallados
docker logs caja_admin_api
docker logs caja_admin_web

# Eliminar contenedores y volúmenes (si necesitas limpiar)
docker-compose down -v
docker-compose up -d

# Verificar conectividad entre contenedores
docker network ls
docker network inspect caja_admin_network
```
