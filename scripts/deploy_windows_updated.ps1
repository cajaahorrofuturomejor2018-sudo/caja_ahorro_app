# ========================================
# Script de Despliegue - Caja de Ahorros Admin
# Windows PowerShell
# ========================================
# Este script actualiza y despliega la aplicación admin
# con todos los fixes más recientes:
# - Campo total_ahorro_voluntario
# - Endpoint de migración
# - Fix de URL de upload
# - Lógica de penalties (2026, vouchers, sin bloqueos)
# - ✅ SUMA ACUMULATIVA EN TOTALES DE USUARIO
# ========================================

Write-Host "🚀 Iniciando despliegue de Caja de Ahorros Admin..." -ForegroundColor Green
Write-Host ""

# Detener y remover contenedores existentes si existen
Write-Host "🛑 Deteniendo contenedores existentes..." -ForegroundColor Yellow
docker stop caja_admin_api caja_admin_web 2>$null
docker rm caja_admin_api caja_admin_web 2>$null
Write-Host "✓ Contenedores removidos" -ForegroundColor Green
Write-Host ""

# Pull de las últimas imágenes
Write-Host "⬇️  Descargando últimas imágenes de Docker Hub..." -ForegroundColor Yellow
docker pull cajawebapk/caja-admin-api:latest
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error al descargar imagen API" -ForegroundColor Red
    exit 1
}
docker pull cajawebapk/caja-admin-web:latest
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error al descargar imagen Web" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Imágenes descargadas correctamente" -ForegroundColor Green
Write-Host ""

# Crear red si no existe (ignorar error si ya existe)
Write-Host "🌐 Creando red Docker..." -ForegroundColor Yellow
docker network create caja_admin_network 2>$null
Write-Host "✓ Red configurada" -ForegroundColor Green
Write-Host ""

# Levantar contenedores
Write-Host "🐳 Levantando contenedores..." -ForegroundColor Yellow
docker run -d --name caja_admin_api --network caja_admin_network --network-alias api -p 8080:8080 cajawebapk/caja-admin-api:latest
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error al levantar contenedor API" -ForegroundColor Red
    exit 1
}

docker run -d --name caja_admin_web --network caja_admin_network -p 80:80 -p 5173:80 cajawebapk/caja-admin-web:latest
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Error al levantar contenedor Web" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Contenedores levantados correctamente" -ForegroundColor Green
Write-Host ""

# Esperar que los servicios estén listos
Write-Host "⏳ Esperando que los servicios estén listos..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Verificar que estén corriendo
Write-Host ""
Write-Host "📊 Estado de contenedores:" -ForegroundColor Cyan
docker ps --filter "name=caja_admin" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
Write-Host ""

# Health check del API
Write-Host "🏥 Verificando health del API..." -ForegroundColor Yellow
$maxRetries = 10
$retryCount = 0
$healthy = $false

while ($retryCount -lt $maxRetries -and -not $healthy) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080/health" -Method GET -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            $healthy = $true
            Write-Host "✓ API respondiendo correctamente" -ForegroundColor Green
        }
    } catch {
        $retryCount++
        Write-Host "  Intento $retryCount/$maxRetries..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
}

if (-not $healthy) {
    Write-Host "⚠️  API no respondió después de $maxRetries intentos" -ForegroundColor Yellow
    Write-Host "   Revisa los logs con: docker logs caja_admin_api" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "✅ Despliegue completado!" -ForegroundColor Green
Write-Host ""
Write-Host "📍 URLs de acceso:" -ForegroundColor Cyan
Write-Host "   • Admin Web: http://localhost" -ForegroundColor White
Write-Host "   • Admin Web (alt): http://localhost:80" -ForegroundColor White
Write-Host "   • API: http://localhost:8080" -ForegroundColor White
Write-Host "   • API Health: http://localhost:8080/health" -ForegroundColor White
Write-Host ""
Write-Host "📋 Comandos útiles:" -ForegroundColor Cyan
Write-Host "   • Ver logs API: docker logs caja_admin_api" -ForegroundColor White
Write-Host "   • Ver logs Web: docker logs caja_admin_web" -ForegroundColor White
Write-Host "   • Detener todo: docker stop caja_admin_api caja_admin_web" -ForegroundColor White
Write-Host "   • Remover todo: docker rm caja_admin_api caja_admin_web" -ForegroundColor White
Write-Host ""
Write-Host "✅ Incluye todos los fixes más recientes:" -ForegroundColor Green
Write-Host "   ✓ Campo total_ahorro_voluntario" -ForegroundColor White
Write-Host "   ✓ Endpoint de migración de ahorro voluntario" -ForegroundColor White
Write-Host "   ✓ Fix de URL de upload (no más /api/api/upload)" -ForegroundColor White
Write-Host "   ✓ Penalties solo desde 2026" -ForegroundColor White
Write-Host "   ✓ Validación de vouchers antes de aplicar multas" -ForegroundColor White
Write-Host "   ✓ Sin bloqueo de depósitos por multas pendientes" -ForegroundColor White
Write-Host "   ✓ Suma acumulativa en totales de usuario (FIX CRÍTICO)" -ForegroundColor Yellow
Write-Host ""
