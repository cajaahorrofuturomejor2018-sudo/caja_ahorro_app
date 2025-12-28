param(
    [string]$Image = "cajawebapk/caja-admin-api:latest",
    [string]$ContainerName = "admin-api",
    [int]$Port = 8080
)

Write-Host "Actualizando y ejecutando '$ContainerName' con la imagen '$Image'..." -ForegroundColor Cyan

# Verificar Docker instalado
try {
    docker --version | Out-Null
} catch {
    Write-Error "Docker no está instalado o no es accesible desde PowerShell. Instala Docker Desktop y vuelve a intentar."; exit 1
}

# Intentar hacer pull de la imagen
try {
    docker pull $Image
} catch {
    Write-Warning "Fallo al hacer pull. Si requiere autenticación, ejecuta 'docker login' y vuelve a correr el script."; throw
}

# Detener y eliminar contenedor previo si existe
$exists = docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq $ContainerName }
if ($exists) {
    Write-Host "Deteniendo contenedor previo '$ContainerName'..." -ForegroundColor Yellow
    try { docker stop $ContainerName | Out-Null } catch {}
    try { docker rm $ContainerName | Out-Null } catch {}
}

# Ejecutar el contenedor
Write-Host "Levantando contenedor '$ContainerName' en puerto $Port..." -ForegroundColor Cyan
$runCmd = @(
    "docker run -d",
    "--name $ContainerName",
    "-p $Port:$Port",
    "$Image"
) -join " "

# Nota: No se pasan variables ni volúmenes porque se requiere ejecución sin ajustes adicionales
Invoke-Expression $runCmd

# Esperar a que responda el endpoint
$maxAttempts = 30
$attempt = 0
$healthy = $false
$healthUrl = "http://localhost:$Port/api/deposits/pending"
Write-Host "Esperando respuesta de $healthUrl ..." -ForegroundColor Cyan

while ($attempt -lt $maxAttempts -and -not $healthy) {
    Start-Sleep -Seconds 1
    try {
        $resp = Invoke-WebRequest -Uri $healthUrl -TimeoutSec 3 -UseBasicParsing
        if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 500) {
            $healthy = $true
            break
        }
    } catch {
        # Ignorar mientras inicia
    }
    $attempt++
}

if ($healthy) {
    Write-Host "Admin API corriendo en http://localhost:$Port" -ForegroundColor Green
} else {
    Write-Warning "El endpoint no respondió a tiempo. Mostrando últimos logs:" 
    try { docker logs --tail 200 $ContainerName } catch {}
    Write-Warning "Si el pull requería autenticación, ejecuta 'docker login' y vuelve a intentarlo."
}
