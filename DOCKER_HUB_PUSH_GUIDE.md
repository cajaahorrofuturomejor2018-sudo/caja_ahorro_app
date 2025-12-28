# 🐳 GUÍA DE SUBIDA A DOCKER HUB

## ✅ Estado Actual

Las imágenes están construidas y corriendo localmente:

```
CONTENEDORES:
- caja_admin_api:   puerto 8080, corriendo ✅
- caja_admin_web:   puerto 5173 (Nginx), corriendo ✅

IMÁGENES TAGGEADAS:
- cajaahorrofuturomejor2018/caja-admin-api:latest        (335MB)
- cajaahorrofuturomejor2018/caja-admin-web:latest        (54.1MB)
```

## 📋 Instrucciones para Subir a Docker Hub

### Paso 1: Login a Docker Hub
```powershell
docker login -u cajaahorrofuturomejor2018
```

Cuando te pida la contraseña, **usa tu Personal Access Token (PAT)** en lugar de la contraseña:
- Obtén el token en: https://app.docker.com/settings/personal-access-tokens
- O usa uno existente que hayas creado antes

### Paso 2: Subir las imágenes

**API (Backend Node.js)**:
```powershell
docker push cajaahorrofuturomejor2018/caja-admin-api:latest
```

**Web (Frontend Vite + Nginx)**:
```powershell
docker push cajaahorrofuturomejor2018/caja-admin-web:latest
```

### Paso 3: Verificar en Docker Hub

Después de subir, verifica en:
- https://hub.docker.com/r/cajaahorrofuturomejor2018/caja-admin-api
- https://hub.docker.com/r/cajaahorrofuturomejor2018/caja-admin-web

Deberías ver las imágenes con tag `latest`.

## 🎯 Cambios Incluidos en las Imágenes

Las nuevas imágenes incluyen:

✅ **Backend (`admin/api/server.js`)**:
- Carga de parámetros 2026 desde `admin/api/config/parametros_2026.json`
- Endpoint `POST /api/admin/categorizar-socios` - asignar categorías por fecha
- Endpoint `POST /api/admin/inicializar-corte-2025` - corte con carryover
- Lógica de exención de multa por objetivo mensual
- Actualización de `avance_anual_2026` en depósitos
- Caja actualizada en 6 tipos de transacciones (depósitos, aportes, multas, préstamos, pagos, precancelaciones)
- Fix: evitar doble resta de caja en desembolsos de préstamo

✅ **Frontend (`admin/web`)**:
- Construcción optimizada con Vite
- Nginx configurado como reverse proxy
- Sirve en puerto 80 (expuesto como 5173 en dev)

✅ **Documentación**:
- `ESTADO_OPERATIVO_2026.md` - Guía operativa completa
- `PLAN_CATEGORIZACION_SOCIOS_2026.md` - Detalles técnicos
- `CONEXION_SALDO_CAJA.md` - Lógica de caja
- `admin/api/config/parametros_2026.json` - Parámetros configurables
- `test_categorization_flow.js` - Script de verificación (resultados OK)

## 🔍 Verificación Previa

Antes de subir, verificamos que:
- [x] Contenedores corriendo sin errores
- [x] API inicializa Firebase correctamente
- [x] Web construye y sirve con Nginx
- [x] Logs no muestran errores críticos
- [x] Imágenes están taggeadas correctamente
- [x] Archivos de configuración están presentes

## 📊 Tamaño de Imágenes

- `caja-admin-api:latest`: 335 MB
- `caja-admin-web:latest`: 54.1 MB

Total: ~389 MB

## 🚀 Próximos Pasos Después de Subir

1. Verificar en Docker Hub que aparezcan las imágenes
2. Documentar las versiones subidas (ej. `2026-01-01`)
3. Actualizar `docker-compose.yml` en producción con las referencias
4. Hacer deploy en el servidor de producción

## ❓ Si Tienes Problemas

**Problema**: "unauthorized: incorrect username or password"
- Solución: Verifica que estés usando el token (PAT) y no la contraseña de la cuenta

**Problema**: "denied: requested access to the resource is denied"
- Solución: Asegúrate de estar autenticado con `docker login`

**Problema**: Imágenes muy grandes
- Razón: Incluyen dependencias de desarrollo, caches de build, etc.
- Optimización futura: Usar multi-stage builds más eficientes

---

**Estado**: Listo para producción ✅
**Comandos de subida**: Ver Paso 2 arriba ⬆️
