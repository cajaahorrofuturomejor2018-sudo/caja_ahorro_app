# Admin API (Node + Express)

This backend uses Firebase Admin SDK to perform admin operations. It verifies the user's Firebase ID token (Bearer token) and checks the presence of `admin` custom claim.

Endpoints:
- `GET /api/deposits` - returns a list of `depositos` from Firestore. Requires admin claim.
- `POST /api/deposits/:id/approve` - sets `estado` to `aprobado` and records `id_admin_aprobador`.
 - `GET /api/deposits` - returns a list of `depositos` from Firestore. Requires admin claim.
 - `POST /api/deposits/:id/approve` - sets `estado` to `aprobado` and records `id_admin_aprobador` and handles distribution and movimientos.
 - `GET /api/users` - list of users.
 - `POST /api/users/:id/role` - set user's role.
 - `POST /api/users/:id/estado` - set user state (activo/inactivo).
 - `GET /api/caja` - get caja saldo.
 - `POST /api/caja` - set caja saldo (admin only).
 - `POST /api/aportes` - admin add aporte directly to a user.
 - `GET /api/aggregate_totals` - aggregated totals for deposits and loans.

Environment:
- `SERVICE_ACCOUNT_PATH` - Absolute path to a Firebase service account JSON, default expects to be mounted at `/run/secrets/serviceAccountKey.json`.
- `PORT` - optional, default 8080.

Docker:
The Dockerfile is prepared for production; the `docker-compose.yml` in repository root runs both the admin-api and the admin-web.

Security:
- Do not commit `serviceAccountKey.json` or any private keys to source control.
- Use environment variables or Docker secrets to provide service account to the container.

Development notes:
- This is a minimal scaffold: integrate with the project's exact Firestore collection shapes and port the approval/distribution logic from `lib/core/services/firestore_service.dart` for complete parity.
