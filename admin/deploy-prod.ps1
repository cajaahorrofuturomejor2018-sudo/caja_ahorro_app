#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy production Caja de Ahorros en Docker. Descarga imágenes y levanta API + Web.

.DESCRIPTION
    Script todo-en-uno para producción:
    1. Descarga imágenes desde Docker Hub
    2. Crea red Docker
    3. Ejecuta API con SECRET montado (C:\caja\serviceAccountKey.json)
    4. Ejecuta Web (Nginx con proxy a API)
    5. Valida que estén vivas en http://localhost:8080/health y http://localhost:5173

.PARAMETER ServiceAccountPath
    Ruta del archivo serviceAccountKey.json en Windows. Default: C:\caja\serviceAccountKey.json

.PARAMETER MockAPI
    Ejecutar en modo stub sin Firestore. Default: false (producción)

.PARAMETER DisableAuth
    Deshabilitar verificación de tokens. Default: false (producción requiere tokens)

.EXAMPLE
    .\deploy-prod.ps1
    # Levanta todo con configuración de producción (requiere C:\caja\serviceAccountKey.json)

.EXAMPLE
    .\deploy-prod.ps1 -MockAPI true
    # Modo desarrollo sin Firestore (para pruebas rápidas)
#>

param(
    [string]$ServiceAccountPath = "C:\caja\serviceAccountKey.json",
    [string]$MockAPI = "false",
    [string]$DisableAuth = "false"
)

$ErrorActionPreference = "Stop"

Write-Host "`n🚀 Caja de Ahorros - Deploy Producción`n" -ForegroundColor Cyan

# 1. Validar que el secreto existe (si no es mock)
if ($MockAPI -eq "false") {
    if (-not (Test-Path $ServiceAccountPath)) {
        Write-Host "❌ ERROR: Archivo de credenciales no encontrado en: $ServiceAccountPath" -ForegroundColor Red
        Write-Host "   Copia el archivo serviceAccountKey.json a esa ubicación." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ Secreto encontrado: $ServiceAccountPath" -ForegroundColor Green
}

# 2. Descargar imágenes
Write-Host "`n📥 Descargando imágenes de Docker Hub..." -ForegroundColor Cyan
try {
    docker pull cajawebapk/caja-admin-api:latest
    docker pull cajawebapk/caja-admin-web:latest
    Write-Host "✅ Imágenes descargadas" -ForegroundColor Green
} catch {
    Write-Host "❌ Error descargando imágenes: $_" -ForegroundColor Red
    exit 1
}

# 3. Crear red (si no existe)
Write-Host "`n🔗 Creando red Docker..." -ForegroundColor Cyan
$networkExists = docker network ls --format "table {{.Name}}" | Select-String "caja_admin_network"
if (-not $networkExists) {
    docker network create caja_admin_network
    Write-Host "✅ Red creada" -ForegroundColor Green
} else {
    Write-Host "✅ Red ya existe" -ForegroundColor Green
}

# 4. Detener contenedores previos (cleanup)
Write-Host "`n🧹 Limpiando contenedores anteriores..." -ForegroundColor Cyan
docker rm -f caja_admin_api caja_admin_web 2>$null | Out-Null

# 5. Ejecutar API
Write-Host "`n🔧 Iniciando API..." -ForegroundColor Cyan
$volumeArg = if ($MockAPI -eq "false") { "-v `"${ServiceAccountPath}:/run/secrets/serviceAccountKey.json:ro`"" } else { "" }

if ($MockAPI -eq "true" -or $DisableAuth -eq "true") {
    Write-Host "   ⚠️  MODO DESARROLLO: Credenciales limitadas" -ForegroundColor Yellow
}

Invoke-Expression @"
docker run -d `
    --name caja_admin_api `
    --restart unless-stopped `
    --network caja_admin_network `
    --network-alias api `
    -p 8080:8080 `
    -e SERVICE_ACCOUNT_PATH=/run/secrets/serviceAccountKey.json `
    -e MOCK_API=$MockAPI `
    -e DISABLE_AUTH=$DisableAuth `
    -e ADMIN_EMAILS=cajaahorrofuturomejor2018@gmail.com `
    $volumeArg `
    cajawebapk/caja-admin-api:latest
"@

Write-Host "✅ API iniciada (caja_admin_api en puerto 8080)" -ForegroundColor Green

# 6. Ejecutar Web
Write-Host "`n🌐 Iniciando Web (Nginx)..." -ForegroundColor Cyan
docker run -d `
    --name caja_admin_web `
    --restart unless-stopped `
    --network caja_admin_network `
    -p 5173:80 `
    cajawebapk/caja-admin-web:latest

Write-Host "✅ Web iniciada (caja_admin_web en puerto 5173)" -ForegroundColor Green

# 7. Esperar a que API esté lista
Write-Host "`n⏳ Esperando que API esté lista..." -ForegroundColor Cyan
$attempts = 0
$maxAttempts = 30
while ($attempts -lt $maxAttempts) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080/health" -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ API en línea" -ForegroundColor Green
            break
        }
    } catch {}
    $attempts++
    Start-Sleep -Seconds 1
}

if ($attempts -ge $maxAttempts) {
    Write-Host "⚠️  API aún no responde después de 30 segundos" -ForegroundColor Yellow
    Write-Host "   Verifica logs: docker logs caja_admin_api" -ForegroundColor Yellow
}

# 8. Validar Web
Write-Host "`n⏳ Esperando que Web esté lista..." -ForegroundColor Cyan
Start-Sleep -Seconds 3
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5173" -UseBasicParsing -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Web en línea" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  Web aún no responde. Revisa: docker logs caja_admin_web" -ForegroundColor Yellow
}

# 9. Resumen final
Write-Host "`n" + ("="*60) -ForegroundColor Cyan
Write-Host "🎉 ¡SISTEMA ACTIVO!" -ForegroundColor Green
Write-Host ("="*60) -ForegroundColor Cyan
Write-Host "`n📱 Acceso:" -ForegroundColor Cyan
Write-Host "   • Panel Admin:  http://localhost:5173" -ForegroundColor Green
Write-Host "   • API:          http://localhost:8080" -ForegroundColor Green
Write-Host "   • Salud API:    http://localhost:8080/health" -ForegroundColor Green

Write-Host "`n🐳 Contenedores:" -ForegroundColor Cyan
docker ps --filter "name=caja_admin" --format "table {{.Names}}`t{{.Status}}"

Write-Host "`n📋 Comandos útiles:" -ForegroundColor Cyan
Write-Host "   Ver logs API:     docker logs -f caja_admin_api" -ForegroundColor Yellow
Write-Host "   Ver logs Web:     docker logs -f caja_admin_web" -ForegroundColor Yellow
Write-Host "   Detener todo:     docker rm -f caja_admin_api caja_admin_web" -ForegroundColor Yellow
Write-Host "   Actualizar:       .\deploy-prod.ps1" -ForegroundColor Yellow

Write-Host "`n"
