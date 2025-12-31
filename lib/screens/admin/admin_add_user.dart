// Admin moved to web: re-export placeholder implementations.
export 'admin_moved.dart';

# Detener contenedor previo si existe
docker stop admin-api; docker rm admin-api

# Levantar con auth deshabilitado SOLO para migrar
docker run -d --name admin-api -p 8080:8080 `
  -e DISABLE_AUTH="true" `
  cajawebapk/caja-admin-api:latest

# Ejecutar la migración
Invoke-WebRequest -Method POST -Uri "http://localhost:8080/api/admin/migrar-ahorro-voluntario"

# Opcional: volver a reiniciar sin DISABLE_AUTH
docker stop admin-api; docker rm admin-api
docker run -d --name admin-api -p 8080:8080 cajawebapk/caja-admin-api:latest
