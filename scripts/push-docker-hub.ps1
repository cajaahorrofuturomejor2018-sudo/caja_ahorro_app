# 🐳 Script para Push de Imágenes Docker a Docker Hub
# 
# Este script tagea y sube las imágenes del sistema a Docker Hub
# Ejecutar después de hacer login con: docker login

param(
    [Parameter(Mandatory=$true)]
    [string]$DockerHubUsername,
    
    [Parameter(Mandatory=$false)]
    [string]$Version = "latest"
)

Write-Host "🐳 PREPARANDO PUSH A DOCKER HUB" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que Docker esté corriendo
$dockerStatus = docker ps 2>$null
if (!$?) {
    Write-Host "❌ ERROR: Docker no está corriendo" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Docker está corriendo" -ForegroundColor Green
Write-Host ""

# Listar imágenes actuales
Write-Host "📦 Imágenes actuales:" -ForegroundColor Yellow
docker images | Select-String -Pattern "admin"
Write-Host ""

# Tagear imagen del API
Write-Host "🏷️  Tageando imagen del API..." -ForegroundColor Yellow
$apiTag = "$DockerHubUsername/caja-ahorro-admin-api:$Version"
docker tag admin-api $apiTag

if ($?) {
    Write-Host "✅ API tageado como: $apiTag" -ForegroundColor Green
} else {
    Write-Host "❌ Error al tagear API" -ForegroundColor Red
    exit 1
}

# Tagear imagen del Web
Write-Host "🏷️  Tageando imagen del Web..." -ForegroundColor Yellow  
$webImageId = docker images -q 4a56ae9d7874
if ($webImageId) {
    $webTag = "$DockerHubUsername/caja-ahorro-admin-web:$Version"
    docker tag $webImageId $webTag
    
    if ($?) {
        Write-Host "✅ Web tageado como: $webTag" -ForegroundColor Green
    } else {
        Write-Host "❌ Error al tagear Web" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "⚠️  No se encontró la imagen del web" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📤 PUSHEANDO A DOCKER HUB..." -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Push del API
Write-Host "📤 Pusheando $apiTag..." -ForegroundColor Yellow
docker push $apiTag

if ($?) {
    Write-Host "✅ API pusheado exitosamente" -ForegroundColor Green
} else {
    Write-Host "❌ Error al pushear API" -ForegroundColor Red
    Write-Host "💡 Asegúrate de haber hecho: docker login" -ForegroundColor Yellow
    exit 1
}

# Push del Web
if ($webImageId) {
    Write-Host "📤 Pusheando $webTag..." -ForegroundColor Yellow
    docker push $webTag
    
    if ($?) {
        Write-Host "✅ Web pusheado exitosamente" -ForegroundColor Green
    } else {
        Write-Host "❌ Error al pushear Web" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "🎉 PUSH COMPLETADO EXITOSAMENTE" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Imágenes disponibles en Docker Hub:" -ForegroundColor Cyan
Write-Host "   - $apiTag" -ForegroundColor White
if ($webImageId) {
    Write-Host "   - $webTag" -ForegroundColor White
}
Write-Host ""
Write-Host "📥 Para descargar en otro servidor:" -ForegroundColor Yellow
Write-Host "   docker pull $apiTag" -ForegroundColor White
if ($webImageId) {
    Write-Host "   docker pull $webTag" -ForegroundColor White
}
Write-Host ""
Write-Host "✅ Proceso completado" -ForegroundColor Green
