# ⚡ Quick Start - Admin Dashboard

Guía ultra-rápida para levantar el dashboard en **5 minutos**.

## 🎯 En Resumen

```bash
# Terminal 1 - Backend
cd admin/api
npm install
npm start

# Terminal 2 - Frontend  
cd admin/web
npm install
VITE_API_URL=http://localhost:8080 npm run dev

# Abrir navegador
http://localhost:5173
```

---

## 📦 Requisitos

- [Node.js 18+](https://nodejs.org)
- `serviceAccountKey.json` de Firebase (opcional si usas MOCK)

---

## 🚀 Paso 1: Backend (2 min)

```bash
# Navegar a directorio
cd caja_ahorro_app/admin/api

# Instalar dependencias
npm install

# Iniciar servidor
npm start
```

**Resultado esperado:**
```
✅ Server running on port 8080
✅ Firebase Admin SDK initialized
```

---

## 🎨 Paso 2: Frontend (2 min)

**En otra terminal:**

```bash
# Navegar
cd caja_ahorro_app/admin/web

# Instalar dependencias
npm install

# Ejecutar
npm run dev
```

**Resultado esperado:**
```
✅ VITE v5.0.0 ready in XXX ms
✅ Local: http://localhost:5173/
```

---

## 🔓 Paso 3: Abrir Dashboard (1 min)

1. Abrir navegador: `http://localhost:5173`
2. Verás pantalla de login
3. Credenciales demo:
   - Email: `admin@example.com` (crear en Firebase)
   - Password: Tu contraseña

---

## 🔐 Si no tienes Firebase...

**Usar MOCK MODE** (datos fake):

En `admin/api/server.js`, línea ~50:

```javascript
const MOCK_API = true; // Cambiar de false a true
```

Luego reiniciar backend:
```bash
npm start
```

Ahora funcionará sin credenciales reales.

---

## 📝 Comandos Útiles

```bash
# Ver logs del backend
npm start  # En admin/api

# Recargar frontend si hay cambios
npm run dev  # En admin/web

# Limpiar caché y reinstalar
rm -rf node_modules package-lock.json
npm install

# Matar proceso en puerto (Windows)
taskkill /F /IM node.exe

# Ver qué está en puerto 8080
netstat -ano | findstr :8080
```

---

## 🎮 Primera Interacción

Una vez en el dashboard:

1. **Ir a tab "Usuarios"**
   - Click "+ Crear Usuario"
   - Ingresar datos: nombre, email, password
   - Click "Crear Usuario"

2. **Ir a tab "Depósitos"**
   - Ver lista de depósitos
   - Click "Aprobar" en uno
   - Confirmar en popup

3. **Ir a tab "Caja"**
   - Ver saldo total
   - Actualizar si quieres

4. **Ir a tab "Reportes"**
   - Ver totales
   - Descargar como JSON/CSV

---

## 🐛 Troubleshooting Rápido

| Problema | Solución |
|----------|----------|
| **"Cannot connect to API"** | ¿Backend en puerto 8080? `npm start` en `admin/api` |
| **"Port already in use"** | `taskkill /F /IM node.exe` (Windows) |
| **"Module not found"** | `npm install` en el directorio correcto |
| **"Login doesn't work"** | Activar MOCK_API en server.js si no tienes Firebase |
| **"No data showing"** | Check Firestore en Firebase Console |
| **"Blank page"** | Abrir DevTools (F12), ver si hay errores |

---

## 📂 Estructura Rápida

```
admin/
├── web/               ← Frontend React (puerto 5173)
│   ├── src/pages/     ← Todos los tabs aquí
│   └── package.json
│
└── api/               ← Backend Express (puerto 8080)
    ├── server.js      ← Endpoints aquí
    └── package.json
```

---

## 🎨 Tabs Principales

```
✅ Usuarios        → CRUD de usuarios
✅ Depósitos       → Aprobar/rechazar depósitos
✅ Préstamos       → Gestionar créditos
✅ Familias        → Crear grupos
✅ Caja            → Ver saldo total
✅ Reportes        → Descargar datos
✅ Configuración   → Parámetros del sistema
✅ Auditoría       → Ver log de cambios
✅ Validaciones    → Validar depósitos pendientes
```

---

## 🎯 Próximos Pasos

Después de levantarlo:

1. **Leer documentación:**
   - `README_DASHBOARD.md` - Guía completa
   - `TESTING_ENDPOINTS.md` - Probar APIs
   - `TROUBLESHOOTING.md` - Resolver problemas

2. **Configurar para producción:**
   - Cambiar `VITE_API_URL` a URL real
   - Actualizar Firestore Rules
   - Crear usuarios admins

3. **Desplegar:**
   - Docker: `docker-compose up`
   - O servidor Linux: Nginx + PM2

---

## ✅ Checklist Inicio Rápido

- [ ] Node.js 18+ instalado: `node -v`
- [ ] Backend corriendo: `npm start` en `admin/api/`
- [ ] Frontend corriendo: `npm run dev` en `admin/web/`
- [ ] Dashboard abierto: http://localhost:5173
- [ ] Login funciona (o MOCK_API = true)
- [ ] Puedo ver al menos un tab (Usuarios)

Si todo ✅, estás listo para usar el dashboard.

---

## 🎓 Aprender Más

```bash
# Ver documentación completa
cat RESUMEN_MEJORAS.md       # Qué cambió
cat README_DASHBOARD.md      # Guía completa
cat TESTING_ENDPOINTS.md     # Probar APIs
cat TROUBLESHOOTING.md       # Resolver problemas
```

---

## 💾 Guardar Cambios

Si haces cambios en el código:

```bash
# Frontend se recarga automático
npm run dev  # Vuelve a recargar

# Backend requiere reinicio
npm start    # Mata y vuelve a iniciar
```

---

## 🔐 Seguridad Básica

**IMPORTANTE para producción:**

1. No usar MOCK_API = true
2. Configurar Firestore Rules
3. Usar contraseñas fuertes
4. Habilitar 2FA en Firebase
5. Usar HTTPS (no HTTP)

---

## 📞 Help

Si algo no funciona:

1. Revisar terminal del backend (¿errores?)
2. DevTools del navegador (F12 → Console)
3. Ver `TROUBLESHOOTING.md`
4. Revisar `TESTING_ENDPOINTS.md` para endpoints

---

## 🎉 ¡Listo!

Ya tienes un dashboard admin profesional, funcional y documentado.

**Disfruta administrando tu Caja de Ahorros.** 🚀

---

**Última actualización:** 2025  
**Versión:** 1.0  
**Tiempo para setup:** 5-10 minutos

