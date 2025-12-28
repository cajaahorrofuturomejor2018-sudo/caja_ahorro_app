# Caja de Ahorros - Despliegue Rápido en Otra Máquina (Windows)

## ✨ Requisitos Previos

- Docker Desktop instalado y ejecutándose
- Archivo `serviceAccountKey.json` en `C:\caja\serviceAccountKey.json` (fuera del repo)

## 🚀 Despliegue en UN Comando

```powershell
# Ubícate en el directorio admin del proyecto
cd C:\Users\trave\app_cajaAhorros\caja_ahorro_app\admin

# Ejecuta el script de despliegue (pull automático, red, API, Web)
.\deploy-prod.ps1
```

¡Listo! El sistema estará completamente operativo sin tocar nada más.

## 📱 Acceso Inmediato

Después de ejecutar `deploy-prod.ps1`:

- **Panel Admin**: http://localhost:5173
- **API**: http://localhost:8080
- **Salud**: http://localhost:8080/health

## 🔧 Opciones Avanzadas (Rara Vez Necesarias)

```powershell
# Modo desarrollo sin Firestore (para testing)
.\deploy-prod.ps1 -MockAPI true

# Modo desarrollo sin verificación de tokens
.\deploy-prod.ps1 -DisableAuth true

# Ruta diferente del secreto (si no es C:\caja\)
.\deploy-prod.ps1 -ServiceAccountPath "D:\secrets\firebase.json"
```

## 🛑 Detener o Actualizar

```powershell
# Detener y limpiar todo
docker rm -f caja_admin_api caja_admin_web

# Actualizar a nuevas versiones (pull + run automático)
.\deploy-prod.ps1
```

## 📊 Ver Estado

```powershell
# Contenedores corriendo
docker ps

# Logs del API
docker logs -f caja_admin_api

# Logs del Web
docker logs -f caja_admin_web
```

## ⚠️ Solución de Problemas

**API no inicia:**
```powershell
docker logs caja_admin_api
# Si dice "serviceAccountKey.json not found", verifica que:
# C:\caja\serviceAccountKey.json exista y el archivo sea válido JSON
```

**Web no conecta a API:**
- Verifica que `caja_admin_api` esté corriendo: `docker ps`
- Revisa logs: `docker logs caja_admin_web`

**Puerto 8080 o 5173 ya en uso:**
- Detén el contenedor anterior: `docker rm -f caja_admin_api caja_admin_web`
- O usa puertos diferentes en `deploy-prod.ps1` (edita las líneas de `-p`)

## 🎯 Resumen

| Acción | Comando |
|--------|---------|
| Desplegar | `.\deploy-prod.ps1` |
| Actualizar | `.\deploy-prod.ps1` (mismo) |
| Detener | `docker rm -f caja_admin_api caja_admin_web` |
| Ver logs | `docker logs -f caja_admin_api` |
