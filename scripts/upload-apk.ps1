# Script para subir APK a GitHub Release
# Reemplaza TU_TOKEN_GITHUB con un Personal Access Token de GitHub

$owner = "cajaahorrofuturomejor2018-sudo"
$repo = "caja_ahorro_app"
$tag = "v1.0.0-beta.1"
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
$apkFileName = "caja-ahorro-app-v1.0.0-beta.1.apk"

# Token de GitHub - IMPORTANTE: Configura esto con tu token
$token = $env:GITHUB_TOKEN
if (-not $token) {
    Write-Host "ERROR: Variable GITHUB_TOKEN no configurada" -ForegroundColor Red
    Write-Host ""
    Write-Host "Para configurarla, ejecuta en PowerShell:"
    Write-Host "`$env:GITHUB_TOKEN = 'tu_personal_access_token_aqui'"
    Write-Host ""
    Write-Host "Para crear un token:"
    Write-Host "  1. Ve a https://github.com/settings/tokens"
    Write-Host "  2. Haz clic en 'Generate new token'"
    Write-Host "  3. Selecciona el scope 'repo' (acceso completo a repos privados y públicos)"
    Write-Host "  4. Copia el token y úsalo arriba"
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Accept" = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

# Verificar que el APK existe
if (-not (Test-Path $apkPath)) {
    Write-Host "ERROR: APK no encontrado en $apkPath" -ForegroundColor Red
    exit 1
}

$fileSize = (Get-Item $apkPath).Length
$fileSizeMB = [math]::Round($fileSize / 1MB, 2)

Write-Host "📱 Subiendo APK a GitHub Release" -ForegroundColor Cyan
Write-Host "  Repositorio: $owner/$repo"
Write-Host "  Tag: $tag"
Write-Host "  Archivo: $apkFileName"
Write-Host "  Tamaño: $fileSizeMB MB"
Write-Host ""

# Paso 1: Obtener información de la release
Write-Host "1️⃣  Buscando release..." -ForegroundColor Yellow
$releaseUrl = "https://api.github.com/repos/$owner/$repo/releases/tags/$tag"

try {
    $releaseResponse = Invoke-WebRequest -Uri $releaseUrl -Headers $headers -Method Get -ErrorAction Stop
    $release = $releaseResponse.Content | ConvertFrom-Json
    $releaseId = $release.id
    $uploadUrl = $release.upload_url -replace '\{\?name,label\}', ''
    Write-Host "   ✅ Release encontrado (ID: $releaseId)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error: Release no encontrado. Crea uno primero en:" -ForegroundColor Red
    Write-Host "      https://github.com/$owner/$repo/releases/new?tag=$tag"
    exit 1
}

# Paso 2: Subir APK
Write-Host "2️⃣  Subiendo APK..." -ForegroundColor Yellow
$uploadEndpoint = "$uploadUrl`?name=$apkFileName"

$fileContent = [System.IO.File]::ReadAllBytes($apkPath)
$uploadHeaders = $headers.Clone()
$uploadHeaders["Content-Type"] = "application/vnd.android.package-archive"

try {
    $uploadResponse = Invoke-WebRequest -Uri $uploadEndpoint -Headers $uploadHeaders -Method Post -Body $fileContent -ErrorAction Stop
    $asset = $uploadResponse.Content | ConvertFrom-Json
    Write-Host "   ✅ APK subido exitosamente" -ForegroundColor Green
    Write-Host ""
    Write-Host "📥 Descarga:" -ForegroundColor Cyan
    Write-Host "   $($asset.browser_download_url)"
    Write-Host ""
    Write-Host "🔗 Release:" -ForegroundColor Cyan
    Write-Host "   https://github.com/$owner/$repo/releases/tag/$tag"
} catch {
    Write-Host "   ❌ Error al subir: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ ¡Completado!" -ForegroundColor Green
