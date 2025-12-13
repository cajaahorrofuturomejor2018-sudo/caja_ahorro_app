@echo off
REM Script para instruir al usuario cómo descargar y instalar el APK
REM O usar curl para subir el APK automáticamente

setlocal enabledelayedexpansion

echo.
echo ========================================
echo   APK Caja de Ahorro - Publicador
echo ========================================
echo.
echo APK compilado y listo en:
echo   build\app\outputs\flutter-apk\app-release.apk
echo.
echo Release creada en GitHub:
echo   v1.0.0-beta.1
echo.
echo Tamaño: ~92 MB
echo.
echo ========================================
echo   OPCIONES DE PUBLICACION
echo ========================================
echo.
echo Opción 1: Subir manualmente (recomendado)
echo   1. Ve a: https://github.com/cajaahorrofuturomejor2018-sudo/caja_ahorro_app/releases/tag/v1.0.0-beta.1
echo   2. Haz clic en "Edit"
echo   3. En "Attach binaries", arrastra el APK
echo   4. Guarda los cambios
echo.
echo Opción 2: Subir automáticamente (requiere token de GitHub)
echo   1. Ejecuta: powershell -ExecutionPolicy Bypass -File scripts\upload-apk.ps1
echo   2. Configura tu GITHUB_TOKEN antes de ejecutar
echo.
echo ========================================
echo.
pause
