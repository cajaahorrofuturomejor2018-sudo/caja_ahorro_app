# 🏦 Panel Administrativo - Caja de Ahorros

Panel web moderno para gestionar usuarios, depósitos, préstamos y configuración.

## 🚀 Inicio Rápido

```powershell
cd admin
docker compose up -d
```

**Acceso:**
- Panel: http://localhost:5173
- API: http://localhost:8080/health

## ✨ Características

- ✅ Sin autenticación compleja (DISABLE_AUTH=true por defecto)
- 💾 Firestore real con service account
- 🎨 UI moderna y responsiva
- 📱 Multi-dispositivo (móvil, tablet, desktop)

## 🛠️ Stack

- Backend: Node.js + Express + Firebase Admin
- Frontend: React 18 + Vite + Axios
- Deploy: Docker + Nginx

## 📡 Endpoints Principales

- `GET /api/users` - Usuarios
- `GET /api/deposits` - Depósitos
- `POST /api/deposits/:id/approve` - Aprobar/rechazar
- `GET /api/prestamos` - Préstamos
- `POST /api/prestamos/:id/approve` - Aprobar/rechazar

## 🐳 Comandos

```powershell
docker compose up -d          # Levantar
docker compose logs -f        # Ver logs
docker compose down           # Detener
docker compose up -d --build  # Reconstruir
```

## ⚙️ Configuración

Archivo: `docker-compose.yml`

```yaml
api:
  environment:
    - DISABLE_AUTH=true    # Sin tokens (escritorio)
    - MOCK_API=false       # Firestore real
```

## 🆘 Troubleshooting

**404 en API**: Usa `http://localhost:5173` (no `api:8080`)  
**Sin datos**: Verifica Firestore tiene registros  
**Logs**: `docker compose logs api`

---

Desarrollado para Caja de Ahorros Futuro Mejor
