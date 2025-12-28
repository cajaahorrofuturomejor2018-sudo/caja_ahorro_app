const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const PdfPrinter = require('pdfmake');

const app = express();
app.use(cors());
app.use(express.json());

// Service account must be mounted or provided via env var
const serviceAccountPath = process.env.SERVICE_ACCOUNT_PATH || '/run/secrets/serviceAccountKey.json';
const serviceAccountInline = process.env.SERVICE_ACCOUNT_JSON || process.env.MOUNTED_SERVICE_ACCOUNT_JSON;
if (!path.isAbsolute(serviceAccountPath)) {
  console.error('[admin-api] SERVICE_ACCOUNT_PATH must be set to absolute path');
}
let firebaseInitialized = false;
try {
  let serviceAccount;
  if (serviceAccountInline) {
    serviceAccount = JSON.parse(serviceAccountInline);
  } else {
    // Read from mounted file by default
    serviceAccount = require(serviceAccountPath);
  }
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'cajaahorroapp.firebasestorage.app' // o 'cajaahorroapp.appspot.com'
  });
  console.log('[admin-api] Firebase Admin initialized');
  firebaseInitialized = true;
} catch (e) {
  console.warn('[admin-api] Firebase Admin not initialized: ' + e.message);
}

// Mock mode for local development when Firebase credentials are not available.
const MOCK_API = (process.env.MOCK_API || 'false').toString() === 'true';
// Disable auth: allow all requests as admin while still using real Firestore
const DISABLE_AUTH = (process.env.DISABLE_AUTH || 'false').toString() === 'true';
if (MOCK_API) {
  console.log('[admin-api] Running in MOCK_API mode — using stubbed responses');
}
if (!MOCK_API && !firebaseInitialized) {
  console.error('[admin-api] Firebase Admin credentials requeridos. Provee serviceAccountKey.json o establece MOCK_API=true para modo stub');
  process.exit(1);
}

// Middleware to verify Firebase ID token sent as Bearer token
async function verifyToken(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.replace(/^Bearer\s+/, '');
  if (MOCK_API || DISABLE_AUTH) {
    // In mock mode accept any token and return an admin user for convenience
    req.user = { uid: DISABLE_AUTH ? 'local-admin' : 'mock-admin', admin: true };
    return next();
  }
  if (!token) return res.status(401).json({ error: 'Missing token' });
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    // Determine admin by multiple strategies to reduce friction
    let isAdmin = !!decoded.admin;
    const email = (decoded.email || '').toLowerCase();
    // 1) Env var whitelist: comma-separated emails
    const allowedList = (process.env.ADMIN_EMAILS || '').toLowerCase().split(',').map(s => s.trim()).filter(Boolean);
    if (!isAdmin && email && allowedList.length > 0 && allowedList.includes(email)) {
      isAdmin = true;
    }
    // 2) Firestore role flag on usuarios: rol == 'admin'|'superadmin'
    if (!isAdmin && decoded.uid) {
      try {
        const snap = await admin.firestore().collection('usuarios').doc(decoded.uid).get();
        if (snap.exists) {
          const rol = (snap.data()?.rol || '').toString().toLowerCase();
          if (rol === 'admin' || rol === 'superadmin') isAdmin = true;
        }
      } catch {}
    }
    req.user = { ...decoded, admin: isAdmin };
    next();
  } catch (e) {
    res.status(401).json({ error: 'Invalid token' });
  }
}

app.get('/', (req, res) => res.json({ ok: true }));

app.get('/health', (req, res) => res.json({ ok: true }));

// Create user endpoint with improved error handling
app.post('/api/users', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  const { nombre, correo, password, rol, telefono, direccion, estado, fotoUrl } = req.body || {};
  if (!correo || !password || !nombre || !rol) return res.status(400).json({ error: 'Missing required fields' });
  try {
    const userRecord = await admin.auth().createUser({ email: correo, password, displayName: nombre });
    const uid = userRecord.uid;
    // Set custom claim admin if role suggests admin privileges
    try {
      if (rol === 'admin' || rol === 'superadmin') {
        await admin.auth().setCustomUserClaims(uid, { admin: true });
      }
    } catch (e) {
      console.warn('[admin-api] Failed to set custom claims', e);
    }
    const db = admin.firestore();
    await db.collection('usuarios').doc(uid).set({
      id: uid,
      nombres: nombre,
      correo: correo,
      rol: rol,
      telefono: telefono || '',
      direccion: direccion || '',
      estado: estado || 'activo',
      foto_url: fotoUrl || '',
      fecha_registro: admin.firestore.FieldValue.serverTimestamp(),
      total_ahorros: 0.0,
      total_prestamos: 0.0,
      total_multas: 0.0,
      total_plazos_fijos: 0.0,
      total_certificados: 0.0,
      ahorro_voluntario: 0.0,
    });
    res.json({ ok: true, id: uid });
  } catch (e) {
    console.error('[admin-api] Error creating user:', e);
    const code = e?.code || e?.errorInfo?.code || '';
    const message = e?.message || e?.errorInfo?.message || e?.toString?.() || '';
    // Handle specific Firebase Auth errors
    if (code === 'auth/email-already-exists' || /already in use|already exists/i.test(message)) {
      return res.status(409).json({ error: 'El email ya está registrado en otro usuario' });
    }
    if (code === 'auth/invalid-email' || /invalid email/i.test(message)) {
      return res.status(400).json({ error: 'Email inválido' });
    }
    if (code === 'auth/weak-password' || /password/i.test(message)) {
      return res.status(400).json({ error: 'Contraseña muy débil' });
    }
    // Generic error
    res.status(500).json({ error: message || 'Error al crear usuario' });
  }
});

app.listen(process.env.PORT || 8080, () => {
  console.log('[admin-api] Listening on ' + (process.env.PORT || 8080));
});

module.exports = app;
