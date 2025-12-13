# Admin Web (React)

This is a minimal React admin UI that uses the Node Admin API to perform administrative actions.

Build & Run locally (requires Node.js):

```powershell
cd admin/web
npm install
npm run dev -- --host
# Or build for production
npm run build
```

Docker (build + serve via Nginx):

```powershell
docker-compose up --build admin-web admin-api
```

Environment:
 - `VITE_API_URL` should be set to the base URL where `admin-api` is available (e.g., `http://localhost:8080`)

Notes:
- This admin web requires Firebase to authenticate admin users. Ensure admin users have a custom claim `admin: true`.
- This is a small scaffold of the real admin web; expand pages and flows as required.
