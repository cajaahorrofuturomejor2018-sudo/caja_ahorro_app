#!/usr/bin/env pwsh
# Script para probar el flujo completo de depósitos

param(
    [string]$ApiUrl = "http://localhost:8080",
    [string]$AdminToken = "test-admin-token"
)

Write-Host "================================" -ForegroundColor Cyan
Write-Host "PRUEBA DE FLUJO COMPLETO DE DEPOSITOS" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Variables globales
$userId = "test-user-id-12345"
$depositId = $null

# Test 1: Crear usuario (si no existe)
Write-Host "`n[TEST 1] Crear usuario de prueba" -ForegroundColor Yellow
$userData = @{
    email = "testuser@example.com"
    password = "TestPassword123!"
    nombre = "Usuario Test"
    apellido = "Apellido Test"
    cedula = "12345678"
    role = "usuario"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$ApiUrl/api/users" -Method POST -Body $userData -ContentType "application/json" -ErrorAction Stop
    if ($response -and $response.uid) {
        $userId = $response.uid
        Write-Host "OK Usuario creado: $userId" -ForegroundColor Green
    }
}
catch {
    # Si obtiene 409, el usuario ya existe, lo cual es esperado
    $statusCode = $_.Exception.Response.StatusCode.Value__
    if ($statusCode -eq 409) {
        Write-Host "OK Usuario ya existe (esperado)" -ForegroundColor Green
    }
    else {
        Write-Host "ERROR creando usuario (código $statusCode): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 2: Crear deposito con validacion correcta
Write-Host "`n[TEST 2] Crear deposito" -ForegroundColor Yellow

$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$depositData = @{
    id_usuario = $userId
    tipo = "ahorro"
    monto = 50.00
    observaciones = "Deposito de prueba"
    comprobante_numero = "TEST-001-$timestamp"
    fecha_deposito_detectada = (Get-Date -Format "dd/MM/yyyy")
} | ConvertTo-Json -Depth 10

try {
    $response = Invoke-RestMethod -Uri "$ApiUrl/api/deposits" -Method POST -Body $depositData -ContentType "application/json" -ErrorAction Stop
    if ($response -and $response.id) {
        $depositId = $response.id
        Write-Host "OK Deposito creado: $depositId" -ForegroundColor Green
    }
}
catch {
    Write-Host "ERROR al crear deposito: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 3: Listar depositos pendientes como admin
Write-Host "`n[TEST 3] Listar depositos pendientes" -ForegroundColor Yellow

$headers = @{
    "Authorization" = "Bearer $AdminToken"
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri "$ApiUrl/api/deposits/pending" -Method GET -Headers $headers -ErrorAction Stop
    if ($response -and $response.Count -gt 0) {
        $pendingCount = ($response | Measure-Object).Count
        Write-Host "OK Depositos pendientes: $pendingCount" -ForegroundColor Green
    }
    else {
        Write-Host "OK Depositos pendientes: 0 o sin respuesta" -ForegroundColor Green
    }
}
catch {
    Write-Host "ERROR Listar depositos pendientes: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Aprobar deposito
Write-Host "`n[TEST 4] Aprobar deposito" -ForegroundColor Yellow

$approveData = @{
    approve = $true
    observaciones = "Aprobado en prueba"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$ApiUrl/api/deposits/$depositId/approve" -Method POST -Body $approveData -ContentType "application/json" -Headers $headers -ErrorAction Stop
    Write-Host "OK Deposito aprobado" -ForegroundColor Green
}
catch {
    Write-Host "ERROR al aprobar deposito: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Probar codigo de error 409 para email duplicado
Write-Host "`n[TEST 5] Validar codigo 409 para email duplicado" -ForegroundColor Yellow

$duplicateUser = @{
    email = "testuser@example.com"
    password = "TestPassword123!"
    nombre = "Otro Usuario"
    apellido = "Otro Apellido"
    cedula = "87654321"
} | ConvertTo-Json

$statusCode = 0
try {
    $response = Invoke-RestMethod -Uri "$ApiUrl/api/users" -Method POST -Body $duplicateUser -ContentType "application/json" -ErrorAction Stop
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.Value__
}

if ($statusCode -eq 409) {
    Write-Host "OK Retorna 409 Conflict para email duplicado" -ForegroundColor Green
}
elseif ($statusCode -eq 400) {
    Write-Host "ERROR Retorna $statusCode (Bad Request) en lugar de 409 (Conflict)" -ForegroundColor Red
}
else {
    Write-Host "ERROR Retorna $statusCode (esperado 409)" -ForegroundColor Red
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "PRUEBAS COMPLETADAS" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan


# Test 4: Aprobar deposito
Write-Host "`n[TEST 4] Aprobar deposito" -ForegroundColor Yellow

$approveData = @{
    approve = $true
    detalleOverride = $null
    observaciones = "Aprobado en prueba"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "$ApiUrl/api/deposits/$depositId/approve" -Method POST -Body $approveData -ContentType "application/json" -Headers $headers -ErrorAction Ignore
if ($response) {
    Write-Host "OK Deposito aprobado" -ForegroundColor Green
}
else {
    Write-Host "ERROR al aprobar deposito" -ForegroundColor Red
}

# Test 5: Probar codigo de error 409 para email duplicado
Write-Host "`n[TEST 5] Validar codigo 409 para email duplicado" -ForegroundColor Yellow

$duplicateUser = @{
    email = "testuser@example.com"
    password = "TestPassword123!"
    nombre = "Otro Usuario"
    apellido = "Otro Apellido"
    cedula = "87654321"
} | ConvertTo-Json

$statusCode = 0
try {
    $response = Invoke-RestMethod -Uri "$ApiUrl/api/users" -Method POST -Body $duplicateUser -ContentType "application/json" -ErrorAction Stop
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.Value__
}

if ($statusCode -eq 409) {
    Write-Host "OK Retorna 409 Conflict para email duplicado" -ForegroundColor Green
}
else {
    Write-Host "ERROR Retorna $statusCode en lugar de 409" -ForegroundColor Red
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "PRUEBAS COMPLETADAS" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
