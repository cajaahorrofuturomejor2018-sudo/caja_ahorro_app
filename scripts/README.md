Scripts to help with Firebase administration and setup for development/testing.

1) Set admin custom claims

- Put a Firebase service account JSON in `scripts/serviceAccountKey.json` (download from Firebase Console > Project Settings > Service Accounts).
- Edit `scripts/admin_uids.json` and add the UIDs of user accounts that must become admins.
- Run:

```bash
node scripts/set_admin_claims.js
```

Note: custom claims take effect when the client refreshes the ID token (user signs out/in) or after token refresh.

2) Deploy Firestore indexes and rules

- To create the composite index required by the app, deploy indexes file and rules:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

You need firebase CLI configured and authenticated and the correct project selected (look into firebase.json). If you want, puedo intentar ejecutar el deploy desde este entorno — confirma que el CLI está autenticado y que quieres que lo haga.
