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

// Parámetros de operación (2026): carga desde archivo para lógica de categorías/aportes/multas
function loadParametros2026() {
  try {
    const p = path.join(__dirname, 'config', 'parametros_2026.json');
    const raw = fs.readFileSync(p, 'utf8');
    const cfg = JSON.parse(raw);
    return cfg;
  } catch (e) {
    return {
      anio: 2026,
      aporte_mensual_base: 25,
      dia_limite_mensual: 10,
      reglas: {
        exencion_multa_si_avance_mes_cumplido: true,
        exencion_multa_si_adelantado: true,
      },
      categorias: []
    };
  }
}

function aporteMensualForUser(userData, parametros) {
  try {
    const cats = Array.isArray(parametros?.categorias) ? parametros.categorias : [];
    const catName = (userData?.categoria || '').toString();
    const found = cats.find(c => (c?.nombre || '') === catName);
    if (found && typeof found.aporte_mensual === 'number') return parseFloat(found.aporte_mensual);
    return parseFloat(parametros?.aporte_mensual_base || 25);
  } catch { return 25; }
}

function objetivoAnualForUser(userData, parametros) {
  try {
    const cats = Array.isArray(parametros?.categorias) ? parametros.categorias : [];
    const catName = (userData?.categoria || '').toString();
    const found = cats.find(c => (c?.nombre || '') === catName);
    if (found && typeof found.aporte_anual_objetivo === 'number') return parseFloat(found.aporte_anual_objetivo);
    const m = aporteMensualForUser(userData, parametros);
    return m * 12;
  } catch { return 25 * 12; }
}

function toJsDate(tsOrDate) {
  try {
    if (!tsOrDate) return new Date();
    if (tsOrDate instanceof Date) return tsOrDate;
    if (typeof tsOrDate === 'string') { const d = new Date(tsOrDate); return isNaN(d.getTime()) ? new Date() : d; }
    if (tsOrDate.toDate) return tsOrDate.toDate();
    return new Date();
  } catch { return new Date(); }
}

function getMonthIndex(dateLike) {
  const d = toJsDate(dateLike);
  return d.getMonth() + 1; // 1-12
}

function dayOfMonth(dateLike) {
  const d = toJsDate(dateLike);
  return d.getDate();
}

// Upload file to Firebase Storage
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } }); // 10MB max

app.post('/api/upload', verifyToken, upload.single('file'), async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
    
    const folder = req.body.folder || 'uploads';
    const timestamp = Date.now();
    const filename = `${folder}/${timestamp}_${req.file.originalname}`;
    
    const bucket = admin.storage().bucket();
    const file = bucket.file(filename);
    
    await file.save(req.file.buffer, {
      metadata: {
        contentType: req.file.mimetype,
      },
    });
    
    // Make file publicly accessible
    await file.makePublic();
    
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filename}`;
    
    res.json({ ok: true, url: publicUrl, filename });
  } catch (e) {
    console.error('[admin-api] Upload error:', e);
    res.status(500).json({ error: e.message || e.toString() });
  }
});

// Example: list deposits from Firestore as admin
app.get('/api/deposits', verifyToken, async (req, res) => {
  if (!req.user.admin) {
    return res.status(403).json({ error: 'Not admin' });
  }
  try {
    const db = admin.firestore();
    let q = db.collection('depositos').limit(200);
    // optional query filtering: ?status=pendiente or ?validado=false
    const status = (req.query.status || '').toString().toLowerCase();
    const validado = req.query.validado;
    if (status) {
      q = db.collection('depositos').where('estado', '==', status).limit(200);
    } else if (typeof validado !== 'undefined') {
      const v = (validado === 'true' || validado === '1');
      q = db.collection('depositos').where('validado', '==', v).limit(200);
    }
    const snap = await q.get();
    const items = snap.docs.map((d) => {
      const data = d.data();
      // Format some commonly used fields for the admin web dashboard
      return {
        id: d.id,
        fecha_deposito: data['fecha_deposito'] ? data['fecha_deposito'].toDate?.()?.toISOString?.() ?? data['fecha_deposito'] : null,
        monto_solicitado: data['monto_solicitado'] ?? data['montoSolicitado'] ?? null,
        monto_aprobado: data['monto_aprobado'] ?? data['montoAprobado'] ?? null,
        estado: data['estado'] ?? null,
        id_usuario: data['id_usuario'] ?? data['idUsuario'] ?? null,
        // include any other fields as needed
        ...data,
      };
    });
    res.json(items);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message || e.toString() });
  }
});

// Soft-delete a deposit (admin) and prevent it from counting while keeping history
app.delete('/api/deposits/:id', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  const id = req.params.id;
  const adminUid = req.user.uid;
  const { motivo = '' } = req.body || {};
  try {
    const db = admin.firestore();
    const ref = db.collection('depositos').doc(id);
    const snap = await ref.get();
    if (!snap.exists) return res.status(404).json({ error: 'Depósito no encontrado' });

    // Do not mutate user totals here to avoid unintended side effects; this is a soft delete.
    await ref.set({
      estado: 'eliminado',
      validado: false,
      eliminado_por: adminUid,
      motivo_eliminacion: motivo,
      fecha_eliminacion: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    res.json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message || e.toString() });
  }
});

// Get users (list)
app.get('/api/users', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  try {
    const db = admin.firestore();
    const snap = await db.collection('usuarios').limit(500).get();
    const items = snap.docs.map(d => ({ id: d.id, ...(d.data() || {}) }));
    res.json(items);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message || e.toString() });
  }
});

// Admin: Categorizar socios por fecha de ingreso y fijar objetivo anual 2026
app.post('/api/admin/categorizar-socios', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  try {
    const db = admin.firestore();
    const params = loadParametros2026();
    const fechaFundacion = params?.fecha_fundacion_iso ? new Date(params.fecha_fundacion_iso) : null;
    const usuariosSnap = await db.collection('usuarios').get();
    let updated = 0;
    for (const doc of usuariosSnap.docs) {
      const udata = doc.data() || {};
      // Determinar fecha de ingreso
      const fIngreso = udata.fecha_ingreso_iso ? new Date(udata.fecha_ingreso_iso) : (udata.fecha_registro?.toDate?.() ? udata.fecha_registro.toDate() : null);
      let categoria = (udata.categoria || '').toString();
      if (!categoria) {
        if (fechaFundacion && fIngreso && fIngreso <= fechaFundacion) {
          categoria = 'fundador';
        } else {
          // Si hay rangos configurados, se podrían usar aquí; por defecto 'nuevo'
          categoria = 'nuevo';
        }
      }
      const objetivoAnual = objetivoAnualForUser({ categoria }, params);
      await db.collection('usuarios').doc(doc.id).set({ categoria, objetivo_anual_2026: objetivoAnual }, { merge: true });
      updated++;
    }
    res.json({ ok: true, usuarios_actualizados: updated });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message || e.toString() });
  }
});

// Admin: Inicializar corte de caja 2025 y avance inicial 2026 (snapshot)
app.post('/api/admin/inicializar-corte-2025', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  try {
    const db = admin.firestore();
    const params = loadParametros2026();
    const fechaCorte = params?.fecha_corte_anual_iso ? new Date(params.fecha_corte_anual_iso) : new Date('2025-12-31T23:59:59Z');
    const usuariosSnap = await db.collection('usuarios').get();
    let processed = 0;
    for (const doc of usuariosSnap.docs) {
      const uid = doc.id;
      const movSnap = await db.collection('movimientos').where('id_usuario', '==', uid).limit(1000).get();
      let sumaDepositosHastaCorte = 0.0;
      for (const mdoc of movSnap.docs) {
        const m = mdoc.data() || {};
        const fecha = m.fecha?.toDate?.() ? m.fecha.toDate() : (m.fecha ? new Date(m.fecha) : null);
        if (!fecha || fecha > fechaCorte) continue;
        const tipo = (m.tipo || '').toString();
        if (tipo === 'deposito' || tipo === 'ahorro') {
          sumaDepositosHastaCorte += parseFloat(m.monto || 0);
        }
      }
      const udata = doc.data() || {};
      // Objetivo anual 2025 basado en categoría (usa parámetros 2026 como referencia si no hay específicos para 2025)
      const objetivoAnual2025 = objetivoAnualForUser(udata, params);
      const carryOver = Math.max(0, sumaDepositosHastaCorte - parseFloat(objetivoAnual2025 || 0));
      const objetivoAnual2026 = objetivoAnualForUser(udata, params);
      // Avance inicial 2026 parte con carryOver (limitado al objetivo anual)
      const avanceInicial2026 = Math.min(carryOver, parseFloat(objetivoAnual2026 || 0));
      await db.collection('usuarios').doc(uid).set({ 
        saldo_corte_2025: sumaDepositosHastaCorte,
        carryover_2025_a_2026: carryOver,
        avance_anual_2026: avanceInicial2026,
        objetivo_anual_2026: objetivoAnual2026
      }, { merge: true });
      processed++;
    }
    res.json({ ok: true, usuarios_procesados: processed });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message || e.toString() });
  }
});

// Movimientos (auditoría)
app.get('/api/movimientos', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  try {
    const db = admin.firestore();
    const snap = await db.collection('movimientos').orderBy('fecha', 'desc').limit(500).get();
    const items = snap.docs.map(d => ({ id: d.id, ...(d.data()||{}) }));
    res.json(items);
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || e.toString() }); }
});

// Reporte: Usuarios y saldos en PDF
app.get('/api/reportes/usuarios', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  try {
    const db = admin.firestore();
    const usuariosSnap = await db.collection('usuarios').get();

    // Obtener última fecha de depósito por usuario
    const depositosSnap = await db.collection('depositos').orderBy('fecha_deposito', 'desc').get();
    const ultimaFechaPorUsuario = {};
    for (const d of depositosSnap.docs) {
      const u = d.data()?.id_usuario;
      const ts = d.data()?.fecha_deposito || d.data()?.fecha_registro;
      if (!u) continue;
      if (!ultimaFechaPorUsuario[u] && ts) {
        try {
          ultimaFechaPorUsuario[u] = ts.toDate ? ts.toDate() : new Date(ts);
        } catch { ultimaFechaPorUsuario[u] = null; }
      }
    }

    const rows = [];
    usuariosSnap.docs.forEach(doc => {
      const u = doc.data();
      const nombre = `${u.nombre || ''} ${u.apellido || ''}`.trim() || (u.displayName || '—');
      const correo = u.email || u.correo || '—';
      const ahorros = parseFloat(u.total_ahorros || 0);
      const plazos = parseFloat(u.total_plazos_fijos || 0);
      const certificados = parseFloat(u.total_certificados || 0);
      const prestamos = parseFloat(u.total_prestamos || 0);
      const multas = parseFloat(u.total_multas || 0);
      const saldo = ahorros + plazos + certificados - prestamos;
      const fechaUlt = ultimaFechaPorUsuario[doc.id] ? new Date(ultimaFechaPorUsuario[doc.id]) : null;
      const fechaStr = fechaUlt ? fechaUlt.toLocaleDateString('es-EC') : '—';
      rows.push([nombre, correo, formatCurrencyLocal(saldo), formatCurrencyLocal(ahorros), formatCurrencyLocal(plazos), formatCurrencyLocal(certificados), formatCurrencyLocal(multas), fechaStr]);
    });

    const fonts = { Roboto: { normal: Buffer.from([]), bold: Buffer.from([]), italics: Buffer.from([]), bolditalics: Buffer.from([]) } };
    const printer = new PdfPrinter(fonts);
    const now = new Date();
    
    // Calcular totales
    let totalSaldo = 0, totalAhorros = 0, totalPlazos = 0, totalCertificados = 0, totalMultas = 0;
    rows.forEach(r => {
      totalSaldo += parseFloat(r[2].replace(/[^0-9.-]/g, '')) || 0;
      totalAhorros += parseFloat(r[3].replace(/[^0-9.-]/g, '')) || 0;
      totalPlazos += parseFloat(r[4].replace(/[^0-9.-]/g, '')) || 0;
      totalCertificados += parseFloat(r[5].replace(/[^0-9.-]/g, '')) || 0;
      totalMultas += parseFloat(r[6].replace(/[^0-9.-]/g, '')) || 0;
    });

    const docDefinition = {
      pageSize: 'A4',
      pageMargins: [28, 40, 28, 40],
      content: [
        { text: '💰 CAJA DE AHORRO', style: 'header', alignment: 'center' },
        { text: 'Reporte Detallado de Usuarios y Saldos', style: 'subheader', alignment: 'center' },
        { text: `Generado: ${now.toLocaleString('es-EC')} | Total Usuarios: ${rows.length}`, style: 'date', alignment: 'center' },
        { text: '\n' },
        {
          table: {
            headerRows: 1,
            widths: ['18%', '18%', '12%', '12%', '12%', '12%', '10%', '6%'],
            body: [
              [
                { text: '👤 Usuario', style: 'tableHeader' },
                { text: '📧 Correo', style: 'tableHeader' },
                { text: '💵 Saldo Total', style: 'tableHeader' },
                { text: '🏦 Ahorros', style: 'tableHeader' },
                { text: '📅 Plazo Fijo', style: 'tableHeader' },
                { text: '🎯 Certificados', style: 'tableHeader' },
                { text: '⚠️ Multas', style: 'tableHeader' },
                { text: '📆 Últ. Depo', style: 'tableHeader' }
              ],
              ...rows.map((r, idx) => r.map((cell, cidx) => ({
                text: cell,
                style: 'tableBody',
                fillColor: idx % 2 === 0 ? '#f8fafc' : '#ffffff',
                border: [1, 1, 1, 1],
                borderColor: '#e2e8f0',
                alignment: cidx > 1 ? 'right' : 'left'
              }))),
              [
                { text: 'TOTAL', style: 'tableTotalLabel', fillColor: '#1e293b' },
                { text: '', style: 'tableBody', fillColor: '#1e293b' },
                { text: formatCurrencyLocal(totalSaldo), style: 'tableTotalValue', fillColor: '#1e293b', alignment: 'right' },
                { text: formatCurrencyLocal(totalAhorros), style: 'tableTotalValue', fillColor: '#1e293b', alignment: 'right' },
                { text: formatCurrencyLocal(totalPlazos), style: 'tableTotalValue', fillColor: '#1e293b', alignment: 'right' },
                { text: formatCurrencyLocal(totalCertificados), style: 'tableTotalValue', fillColor: '#1e293b', alignment: 'right' },
                { text: formatCurrencyLocal(totalMultas), style: 'tableTotalValue', fillColor: '#1e293b', alignment: 'right' },
                { text: '', style: 'tableBody', fillColor: '#1e293b' }
              ]
            ]
          },
          layout: {
            hLineWidth: (i, node) => i === 0 || i === node.table.body.length ? 2 : 1,
            vLineWidth: () => 1,
            hLineColor: () => '#cbd5e1',
            vLineColor: () => '#e2e8f0',
            paddingLeft: () => 8,
            paddingRight: () => 8,
            paddingTop: () => 6,
            paddingBottom: () => 6
          }
        },
        { text: '\n' },
        {
          columns: [
            {
              stack: [
                { text: '📊 Resumen por Tipo', style: 'summaryTitle' },
                { text: `Ahorros Totales: ${formatCurrencyLocal(totalAhorros)}`, style: 'summaryRow' },
                { text: `Plazos Fijos: ${formatCurrencyLocal(totalPlazos)}`, style: 'summaryRow' },
                { text: `Certificados: ${formatCurrencyLocal(totalCertificados)}`, style: 'summaryRow' },
                { text: `Multas Acumuladas: ${formatCurrencyLocal(totalMultas)}`, style: 'summaryRow' }
              ]
            },
            {
              stack: [
                { text: '📈 Estadísticas', style: 'summaryTitle' },
                { text: `Total Usuarios: ${rows.length}`, style: 'summaryRow' },
                { text: `Saldo Neto Total: ${formatCurrencyLocal(totalSaldo)}`, style: 'summaryRow', bold: true },
                { text: `Promedio por Usuario: ${formatCurrencyLocal(totalSaldo / rows.length)}`, style: 'summaryRow' }
              ]
            }
          ],
          columnGap: 20
        }
      ],
      styles: {
        header: { fontSize: 20, bold: true, color: '#0ea5e9', marginBottom: 4 },
        subheader: { fontSize: 13, color: '#475569', marginBottom: 2, bold: true },
        date: { fontSize: 9, color: '#64748b', marginBottom: 14 },
        tableHeader: { fontSize: 10, bold: true, color: '#ffffff', alignment: 'center', backgroundColor: '#0ea5e9' },
        tableBody: { fontSize: 8.5, alignment: 'left' },
        tableTotalLabel: { fontSize: 9, bold: true, color: '#ffffff', alignment: 'left' },
        tableTotalValue: { fontSize: 9, bold: true, color: '#10b981', alignment: 'right' },
        summaryTitle: { fontSize: 11, bold: true, color: '#0ea5e9', marginBottom: 6 },
        summaryRow: { fontSize: 9, color: '#475569', marginBottom: 4 }
      },
      footer: (currentPage, pageCount) => ({
        columns: [
          { text: `Página ${currentPage} de ${pageCount}`, alignment: 'center', fontSize: 8, color: '#94a3b8' }
        ],
        margin: [28, 10]
      })
    };

    const pdfDoc = printer.createPdfKitDocument(docDefinition);
    const chunks = [];
    pdfDoc.on('data', (d) => chunks.push(d));
    pdfDoc.on('end', () => {
      const result = Buffer.concat(chunks);
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', 'attachment; filename="reporte_usuarios.pdf"');
      res.send(result);
    });
    pdfDoc.end();
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message || e.toString() });
  }
});

function formatCurrencyLocal(n) {
  try { return new Intl.NumberFormat('es-EC', { style: 'currency', currency: 'USD', minimumFractionDigits: 2 }).format(n || 0); } catch { return `$${(n||0).toFixed(2)}`; }
}

// Pending deposits (validations queue)
app.get('/api/deposits/pending', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  try {
    const db = admin.firestore();
    // Removed orderBy to avoid index requirement; will sort in memory
    const snap = await db.collection('depositos').where('validado', '==', false).limit(200).get();
    const items = snap.docs.map(d => ({ id: d.id, ...(d.data()||{}) }));
    // Sort by fecha_registro descending in memory
    items.sort((a, b) => {
      const dateA = a.fecha_registro?.toDate?.() || a.fecha_registro?._seconds ? new Date(a.fecha_registro._seconds * 1000) : new Date(0);
      const dateB = b.fecha_registro?.toDate?.() || b.fecha_registro?._seconds ? new Date(b.fecha_registro._seconds * 1000) : new Date(0);
      return dateB - dateA; // descending
    });
    res.json(items);
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || e.toString() }); }
});

// Create user
app.post('/api/users', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  const { nombre, correo, email, password, rol, telefono, direccion, estado, fotoUrl } = req.body || {};
  // Accept both 'email' and 'correo' field names
  const emailToUse = email || correo;
  const roleToUse = rol || 'usuario';
  if (!emailToUse || !password || !nombre) return res.status(400).json({ error: 'Missing required fields' });
  try {
    const userRecord = await admin.auth().createUser({ email: emailToUse, password, displayName: nombre });
    const uid = userRecord.uid;
    // Set custom claim admin if role suggests admin privileges
    try {
      if (roleToUse === 'admin' || roleToUse === 'superadmin') {
        await admin.auth().setCustomUserClaims(uid, { admin: true });
      } else {
        await admin.auth().setCustomUserClaims(uid, { admin: false });
      }
    } catch (e) {
      console.warn('[admin-api] Failed to set custom claims', e);
    }
    const db = admin.firestore();
    await db.collection('usuarios').doc(uid).set({
      id: uid,
      nombres: nombre,
      correo: emailToUse,
      email: emailToUse,
      rol: roleToUse,
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
    res.json({ ok: true, uid });
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
    res.status(500).json({ error: message || 'Error al crear usuario' });
  }
});

// Update user role
app.post('/api/users/:id/role', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  const id = req.params.id; const { role } = req.body || {};
  if (!role) return res.status(400).json({ error: 'Missing role' });
  try {
    const db = admin.firestore();
    await db.collection('usuarios').doc(id).update({ rol: role });
    try {
      // set custom claim admin for admin role
      if (role === 'admin' || role === 'superadmin') {
        await admin.auth().setCustomUserClaims(id, { admin: true });
      } else {
        await admin.auth().setCustomUserClaims(id, { admin: false });
      }
    } catch (err) {
      console.warn('[admin-api] Could not set custom claims for role change', err);
    }
    res.json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || e.toString() }); }
});

// Update user estado
app.post('/api/users/:id/estado', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  const id = req.params.id; const { estado } = req.body || {};
  if (!estado) return res.status(400).json({ error: 'Missing estado' });
  try {
    const db = admin.firestore();
    await db.collection('usuarios').doc(id).update({ estado: estado });
    res.json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || e.toString() }); }
});

// Get caja saldo - calcula dinámicamente desde saldos de usuarios
app.get('/api/caja', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  try {
    const db = admin.firestore();
    // Calcular saldo dinámico sumando todos los total_ahorros, total_certificados, total_plazos_fijos de TODOS los usuarios
    // Menos los total_prestamos que son adeudos
    const usuariosSnap = await db.collection('usuarios').get();
    let saldoDinamico = 0.0;
    let totalAhorros = 0.0;
    let totalCertificados = 0.0;
    let totalPlazos = 0.0;
    let totalPrestamos = 0.0;
    let totalMultas = 0.0;

    usuariosSnap.docs.forEach(doc => {
      const usuario = doc.data();
      const ahorros = parseFloat(usuario.total_ahorros || 0);
      const certificados = parseFloat(usuario.total_certificados || 0);
      const plazos = parseFloat(usuario.total_plazos_fijos || 0);
      const prestamos = parseFloat(usuario.total_prestamos || 0);
      const multas = parseFloat(usuario.total_multas || 0);

      // Sumar totales para el resumen
      totalAhorros += ahorros;
      totalCertificados += certificados;
      totalPlazos += plazos;
      totalPrestamos += prestamos;
      totalMultas += multas;

      // El saldo de caja es: lo que los usuarios han ahorrado/invertido MENOS lo que les hemos prestado
      // Fórmula: (ahorros + certificados + plazos_fijos) - prestamos + multas recaudadas
      saldoDinamico += (ahorros + certificados + plazos - prestamos + multas);
    });

    // Retornar saldo dinámico y detalles
    const estadoSnap = await db.collection('caja').doc('estado').get();
    const saldoAlmacenado = estadoSnap.exists ? parseFloat(estadoSnap.data().saldo || 0) : 0;
    res.json({ 
      saldo: saldoDinamico, 
      saldo_almacenado: saldoAlmacenado,
      detalle: {
        total_ahorros: totalAhorros,
        total_certificados: totalCertificados,
        total_plazos_fijos: totalPlazos,
        total_prestamos: totalPrestamos,
        total_multas: totalMultas
      },
      fecha_calculo: new Date().toISOString()
    });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || e.toString() }); }
});

// Get config
app.get('/api/config', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  try {
    const db = admin.firestore();
    const snap = await db.collection('configuracion').doc('general').get();
    if (snap.exists) return res.json(snap.data() || {});
    const snap2 = await db.collection('configuracion_global').doc('parametros').get();
    if (snap2.exists) return res.json(snap2.data() || {});
    res.json({});
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || e.toString() }); }
});

// Update config
app.post('/api/config', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  const payload = req.body || {};
  try {
    const db = admin.firestore();
    await db.collection('configuracion').doc('general').set(payload, { merge: true });
    res.json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || e.toString() }); }
});

// Set caja saldo
app.post('/api/caja', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  const { saldo } = req.body || {};
  if (typeof saldo === 'undefined') return res.status(400).json({ error: 'Missing saldo' });
  try {
    const db = admin.firestore();
    await db.collection('caja').doc('estado').set({ saldo: saldo, modificado_por: req.user.uid, fecha_modificacion: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    res.json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || e.toString() }); }
});

// Add aporte (adminAddAporte)
app.post('/api/aportes', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  const { idUsuario, tipo, monto, descripcion, archivoUrl } = req.body || {};
  if (!idUsuario || !tipo || typeof monto === 'undefined') return res.status(400).json({ error: 'Missing params' });
  try {
    const db = admin.firestore();
    const docRef = db.collection('depositos').doc();
    const payload = { id_usuario: idUsuario, tipo: tipo, monto: monto, descripcion: descripcion || 'Aporte registrado por admin', archivo_url: archivoUrl || '', validado: true, id_admin: req.user.uid, fecha_deposito: admin.firestore.FieldValue.serverTimestamp(), fecha_registro: admin.firestore.FieldValue.serverTimestamp() };
    await docRef.set(payload);
    // update totals and movimientos within a transaction
    await db.runTransaction(async (tx) => {
      const userRef = db.collection('usuarios').doc(idUsuario);
      const snap = await tx.get(userRef);
      if (!snap.exists) return;
      const data = snap.data();
      const field = (() => { switch(tipo){ case 'plazo_fijo': return 'total_plazos_fijos'; case 'certificado': return 'total_certificados'; case 'pago_prestamo': return 'total_prestamos'; default: return 'total_ahorros'; } })();
      const current = (data[field] || 0) + monto;
      tx.update(userRef, { [field]: current });
      tx.set(db.collection('movimientos').doc(), { id_usuario: idUsuario, tipo: tipo || 'deposito', referencia_id: docRef.id, monto: monto, fecha: admin.firestore.FieldValue.serverTimestamp(), descripcion: descripcion || 'Aporte admin', registrado_por: req.user.uid });
      // Actualizar caja con el aporte registrado por admin
      const cajaRefAporte = db.collection('caja').doc('estado');
      const cajaSnapAporte = await tx.get(cajaRefAporte);
      let cajaSaldoAporte = 0.0;
      if (cajaSnapAporte.exists) cajaSaldoAporte = parseFloat(cajaSnapAporte.data().saldo || 0);
      tx.update(cajaRefAporte, { saldo: cajaSaldoAporte + parseFloat(monto) });
      // 📈 Actualizar avance anual 2026 si el aporte corresponde a ahorro/deposito
      try {
        const params2026 = loadParametros2026();
        const anioCfg = parseInt(params2026?.anio || 2026, 10);
        const now = new Date();
        if (now.getFullYear() === anioCfg && (tipo === 'ahorro' || tipo === 'deposito' || !tipo)) {
          const udata = snap.data() || {};
          const avanceActual = parseFloat(udata?.avance_anual_2026 || 0);
          const nuevoAvance = avanceActual + parseFloat(monto || 0);
          const objetivoAnual = objetivoAnualForUser(udata, params2026);
          tx.update(userRef, {
            avance_anual_2026: nuevoAvance,
            objetivo_anual_2026: udata?.objetivo_anual_2026 || objetivoAnual,
          });
        }
      } catch (e) { /* noop */ }
    });
    res.json({ ok: true, id: docRef.id });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || e.toString() }); }
});

// Aggregated totals
app.get('/api/aggregate_totals', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  try {
    const db = admin.firestore();
    let totalDepositos = 0.0; let totalPrestamos = 0.0;
    const depSnap = await db.collection('depositos').get(); depSnap.docs.forEach(d => { totalDepositos += parseFloat(d.data().monto || 0); });
    const preSnap = await db.collection('prestamos').get(); preSnap.docs.forEach(d => { totalPrestamos += parseFloat(d.data().monto_aprobado || 0); });
    res.json({ total_depositos: totalDepositos, total_prestamos: totalPrestamos });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || e.toString() }); }
});

// Approve a deposit - this is a basic version; advanced distribution logic isn't implemented yet
// Approve or reject a deposit - simplified endpoint
app.post('/api/deposits/:id/approve', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  const depositId = req.params.id;
  const adminUid = req.user.uid;
  const { approve = true, observaciones = '' } = req.body || {};
  try {
    const db = admin.firestore();
    const depRef = db.collection('depositos').doc(depositId);
    
    await depRef.update({
      validado: approve,
      estado: approve ? 'aprobado' : 'rechazado',
      id_admin: adminUid,
      observaciones: observaciones || '',
      fecha_revision: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    res.json({ ok: true, message: approve ? 'Deposito aprobado' : 'Deposito rechazado' });
  } catch (e) {
    console.error('[admin-api] Error approving deposit:', e);
    res.status(500).json({ error: e.message || 'Error al procesar deposito' });
  }
});

// Approve or reject a loan
app.post('/api/prestamos/:id/approve', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  const id = req.params.id;
  const adminUid = req.user.uid;
  const { approve = true, montoAprobado = null, interes = null, plazoMeses = null, observaciones = '', documentoContratoUrl = '' } = req.body || {};
  try {
    const db = admin.firestore();
    await db.runTransaction(async (tx) => {
      // IMPORTANT: All reads must happen before writes in Firestore transactions
      const preRef = db.collection('prestamos').doc(id);
      const preSnap = await tx.get(preRef);
      if (!preSnap.exists) throw new Error('Préstamo no encontrado');
      const data = preSnap.data() || {};
      
      // Read usuario data first (before any writes)
      const usuarioId = data.id_usuario;
      let usuarioSnap = null;
      let usuarioRef = null;
      if (usuarioId) {
        usuarioRef = db.collection('usuarios').doc(usuarioId);
        usuarioSnap = await tx.get(usuarioRef);
      }
      
      // Now we can do writes
      if (!approve) {
        tx.update(preRef, { estado: 'rechazado', estado_usuario: 'rechazado', id_admin_aprobador: adminUid, observaciones: observaciones || '', fecha_revision: admin.firestore.FieldValue.serverTimestamp() });
        return;
      }
      // Validación: requerir contrato PDF para aprobar
      const existingContrato = (documentoContratoUrl || data.documento_contrato_url || '').toString();
      if (!existingContrato) {
        throw new Error('Se requiere subir el contrato PDF antes de aprobar el préstamo');
      }
      const montoSolicitud = parseFloat(data.monto_solicitado || 0);
      const finalMonto = montoAprobado != null ? parseFloat(montoAprobado) : montoSolicitud;
      const intPlazo = plazoMeses != null ? parseInt(plazoMeses, 10) : (parseInt(data.plazo_meses || 12, 10) || 12);
      const rate = (interes != null ? parseFloat(interes) : parseFloat(data.interes || 0)) / 100.0;
      let cuota = 0.0;
      if (rate > 0) {
        const monthlyRate = rate / 12.0;
        const denom = 1 - 1 / Math.pow(1 + monthlyRate, intPlazo);
        cuota = denom !== 0 ? (finalMonto * monthlyRate / denom) : finalMonto / intPlazo;
      } else {
        cuota = finalMonto / intPlazo;
      }
      const fechaInicio = new Date();
      const fechaFin = new Date(fechaInicio.getFullYear(), fechaInicio.getMonth() + intPlazo, fechaInicio.getDate());
      const proximaCuota = new Date(fechaInicio.getFullYear(), fechaInicio.getMonth() + 1, fechaInicio.getDate());
      // Leer caja antes de escribir para ajustar el saldo por desembolso
      const cajaRef = db.collection('caja').doc('estado');
      const cajaSnapCaja = await tx.get(cajaRef);
      let cajaSaldoActual = 0.0;
      if (cajaSnapCaja.exists) cajaSaldoActual = parseFloat(cajaSnapCaja.data().saldo || 0);
      
      // 💰 ACTUALIZAR CAJA: Desembolso de préstamo RESTA del saldo (egreso)
      // La lógica es: caja presta $1000 → saldo disminuye $1000
      tx.update(cajaRef, { saldo: cajaSaldoActual - finalMonto });

      tx.update(preRef, {
        estado: 'activo',
        estado_usuario: 'activo',
        id_admin_aprobador: adminUid,
        monto_aprobado: finalMonto,
        cuota_mensual: cuota,
        interes: (interes != null ? parseFloat(interes) : data.interes || 0),
        plazo_meses: intPlazo,
        fecha_inicio: admin.firestore.FieldValue.serverTimestamp(),
        fecha_fin: admin.firestore.Timestamp.fromDate(fechaFin),
        proxima_fecha_pago: admin.firestore.Timestamp.fromDate(proximaCuota),
        observaciones: observaciones || '',
        fecha_aprobacion: admin.firestore.FieldValue.serverTimestamp(),
        saldo_pendiente: finalMonto,
        meses_restantes: intPlazo,
        documento_contrato_url: documentoContratoUrl || data.documento_contrato_url || '',
      });
      // movimiento contable de desembolso
      tx.set(db.collection('movimientos').doc(), {
        id_usuario: data.id_usuario || '',
        tipo: 'prestamo_desembolso',
        referencia_id: id,
        monto: finalMonto,
        fecha: admin.firestore.FieldValue.serverTimestamp(),
        descripcion: 'Desembolso préstamo aprobado',
        registrado_por: adminUid,
      });
      // update user's total_prestamos (data already read above)
      if (usuarioSnap && usuarioSnap.exists && usuarioRef) {
        const usuarioData = usuarioSnap.data() || {};
        const currentPrestamos = parseFloat(usuarioData.total_prestamos || 0);
        tx.update(usuarioRef, { total_prestamos: currentPrestamos + finalMonto });
      }
    });
    // Optionally, notify the user
    try {
      const db2 = admin.firestore();
      const pre = await db2.collection('prestamos').doc(id).get();
      const uid = pre.data()?.id_usuario;
      if (uid) {
        await db2.collection('notificaciones').add({ id_usuario: uid, titulo: 'Préstamo aprobado', mensaje: 'Su préstamo ha sido aprobado. Ciclo de pagos iniciado.', tipo: 'aprobacion', estado: 'enviada', fecha_envio: admin.firestore.FieldValue.serverTimestamp(), registrado_por: adminUid, });
      }
    } catch (e) { console.warn('[admin-api] notify user error', e); }
    res.json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || e.toString() }); }
});

// Precancelar un préstamo (usuario paga en un solo pago)
app.post('/api/prestamos/:id/precancelar', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  const id = req.params.id;
  const adminUid = req.user.uid;
  try {
    const db = admin.firestore();
    await db.runTransaction(async (tx) => {
      const preRef = db.collection('prestamos').doc(id);
      const preSnap = await tx.get(preRef);
      if (!preSnap.exists) throw new Error('Préstamo no encontrado');
      const data = preSnap.data() || {};
      
      // Cambiar a PRESTAMO FINALIZADO
      tx.update(preRef, {
        estado: 'finalizado',
        estado_usuario: 'finalizado',
        saldo_pendiente: 0,
        meses_restantes: 0,
        fecha_cancelacion: admin.firestore.FieldValue.serverTimestamp(),
        precancelado_por: adminUid,
        precancelado_en: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Registrar movimiento de precancelación
      tx.set(db.collection('movimientos').doc(), {
        id_usuario: data.id_usuario || '',
        tipo: 'prestamo_precancelacion',
        referencia_id: id,
        monto: parseFloat(data.saldo_pendiente || 0),
        fecha: admin.firestore.FieldValue.serverTimestamp(),
        descripcion: 'Préstamo precancelado por pago en un solo pago',
        registrado_por: adminUid,
      });
      // Actualizar caja: precancelación incrementa saldo por el pago
      const cajaRefPre = db.collection('caja').doc('estado');
      const cajaSnapPre = await tx.get(cajaRefPre);
      let cajaSaldoPre = 0.0;
      if (cajaSnapPre.exists) cajaSaldoPre = parseFloat(cajaSnapPre.data().saldo || 0);
      const montoPre = parseFloat(data.saldo_pendiente || 0);
      tx.update(cajaRefPre, { saldo: cajaSaldoPre + montoPre });
    });
    
    // Notificar
    try {
      const db2 = admin.firestore();
      const pre = await db2.collection('prestamos').doc(id).get();
      const uid = pre.data()?.id_usuario;
      if (uid) {
        await db2.collection('notificaciones').add({ 
          id_usuario: uid, 
          titulo: 'Préstamo Finalizado', 
          mensaje: 'Tu préstamo ha sido finalizado. Ya no se cobrarán más cuotas.', 
          tipo: 'finalizacion', 
          estado: 'enviada', 
          fecha_envio: admin.firestore.FieldValue.serverTimestamp(), 
          registrado_por: adminUid, 
        });
      }
    } catch (e) { console.warn('[admin-api] notify error', e); }
    
    res.json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || e.toString() }); }
});

// Get prestamos list
app.get('/api/prestamos', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  try {
    const db = admin.firestore();
    const snap = await db.collection('prestamos').limit(500).get();
    const items = snap.docs.map(d => ({ id: d.id, ...(d.data()||{}) }));
    res.json(items);
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || e.toString() }); }
});

// Add a payment to a loan (admin)
app.post('/api/prestamos/:id/pagos', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  const id = req.params.id; const pago = req.body || {};
  try {
    const db = admin.firestore();
    await db.runTransaction(async (tx) => {
      const preRef = db.collection('prestamos').doc(id);
      const preSnap = await tx.get(preRef);
      if (!preSnap.exists) throw new Error('Préstamo no encontrado');
      const data = preSnap.data() || {};
      const historial = Array.isArray(data.historial_pagos) ? [...data.historial_pagos] : [];
      historial.push(pago);
      const montoAprobado = parseFloat(data.monto_aprobado || 0);
      const cuota = parseFloat(data.cuota_mensual || 0);
      let totalPagado = 0.0;
      for (const h of historial) { totalPagado += parseFloat(h.monto || 0); }
      const saldoPendiente = Math.max(0, montoAprobado - totalPagado);
      let mesesRestantes = 0; if (cuota > 0) mesesRestantes = Math.ceil(saldoPendiente / cuota);
      const updates = { historial_pagos: historial, saldo_pendiente: saldoPendiente, meses_restantes: mesesRestantes, fecha_ultimo_pago: admin.firestore.FieldValue.serverTimestamp() };
      if (saldoPendiente <= 0.001) { updates.estado = 'cancelado'; updates.fecha_cancelacion = admin.firestore.FieldValue.serverTimestamp(); }
      tx.update(preRef, updates);
      // crear movimiento
      tx.set(db.collection('movimientos').doc(), { id_usuario: data.id_usuario || '', tipo: 'pago_prestamo', referencia_id: id, monto: pago.monto || pago['monto'] || 0, fecha: admin.firestore.FieldValue.serverTimestamp(), descripcion: pago.descripcion || 'Pago préstamo', registrado_por: req.user.uid });
      // Actualizar caja: pago de préstamo incrementa saldo
      const cajaRefPago = db.collection('caja').doc('estado');
      const cajaSnapPago = await tx.get(cajaRefPago);
      let cajaSaldoPago = 0.0;
      if (cajaSnapPago.exists) cajaSaldoPago = parseFloat(cajaSnapPago.data().saldo || 0);
      const montoPago = parseFloat(pago.monto || pago['monto'] || 0);
      tx.update(cajaRefPago, { saldo: cajaSaldoPago + montoPago });
    });
    res.json({ ok: true });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || e.toString() }); }
});

// Create a deposit (optionally approve it) - admin action to create & distribute
app.post('/api/deposits', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  try {
    const db = admin.firestore();
    const payload = req.body || {};
    // Insert defaults
    if (!payload.id_usuario || typeof payload.monto === 'undefined') return res.status(400).json({ error: 'Missing id_usuario or monto' });
    const docRef = db.collection('depositos').doc();
    payload.fecha_registro = admin.firestore.FieldValue.serverTimestamp();
    payload.fecha_deposito = payload.fecha_deposito || admin.firestore.FieldValue.serverTimestamp();
    await docRef.set(payload);
    // If 'approve' flag is present, the admin should call /api/deposits/:id/approve separately.
    res.json({ ok: true, id: docRef.id });
  } catch (e) { console.error(e); res.status(500).json({ error: e.message || e.toString() }); }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`[admin-api] Listening on ${port}`));


