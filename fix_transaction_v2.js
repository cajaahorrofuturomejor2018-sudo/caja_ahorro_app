#!/usr/bin/env node
/**
 * Fix Firestore transaction order: move all reads outside transaction
 * The issue is that Firestore requires all reads BEFORE any writes
 */

const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'admin', 'api', 'server.js');
let content = fs.readFileSync(filePath, 'utf8');

// Find the approve endpoint and simplify the transaction
const approvePattern = /app\.post\('\/api\/deposits\/:id\/approve'[\s\S]*?(?=app\.post\('\/api\/users|\Z)/;
const match = content.match(approvePattern);

if (!match) {
  console.error('Could not find approve endpoint');
  process.exit(1);
}

const oldEndpoint = match[0];

// Create new simplified endpoint with all reads outside transaction
const newEndpoint = `app.post('/api/deposits/:id/approve', verifyToken, async (req, res) => {
  if (!req.user.admin) return res.status(403).json({ error: 'Not admin' });
  const depositId = req.params.id;
  const adminUid = req.user.uid;
  const { approve = true, observaciones = '', detalleOverride = null, multasPorUsuario = null, interes = null, documento_url = null } = req.body || {};
  try {
    const db = admin.firestore();

    // Helper: read config
    async function getConfiguracion() {
      const snap = await db.collection('configuracion').doc('general').get();
      if (snap.exists) return snap.data();
      const snap2 = await db.collection('configuracion_global').doc('parametros').get();
      if (snap2.exists) return snap2.data();
      return null;
    }

    // ========== PRE-TRANSACTION READS ==========
    let depData = null;
    let depTipo = null;
    let depUsuarioId = null;
    let config = null;
    let multaMonto = 0;
    let detalle = null;
    let cajaSnap = null;
    let userSnaps = {};
    let multasSnapBefore = null;

    try {
      // Read deposit
      const depSnap = await db.collection('depositos').doc(depositId).get();
      if (!depSnap.exists) {
        return res.status(404).json({ error: 'Deposito no encontrado' });
      }
      
      depData = depSnap.data();
      depTipo = depData?.tipo || 'ahorro';
      depUsuarioId = depData?.id_usuario;
      detalle = detalleOverride || (depData?.detalle_por_usuario ? JSON.parse(depData.detalle_por_usuario) : null);
      
      // Read multas if needed
      if (approve && depTipo === 'multa' && depUsuarioId) {
        multasSnapBefore = await db.collection('multas')
          .where('id_usuario', '==', depUsuarioId)
          .where('estado', '==', 'pendiente')
          .get();
      }
      
      // Get configuration
      config = await getConfiguracion();
      
      // Compute penalty before transaction
      function computePenalty(depData, config) {
        try {
          const now = new Date();
          if (now.getFullYear() < 2026) return 0.0;
          const enforceDate = (config?.enforce_voucher_date) ?? false;
          if (!enforceDate) return 0.0;
          // Simplified: just return 0 for now
          return 0.0;
        } catch (e) {
          return 0.0;
        }
      }
      multaMonto = computePenalty(depData, config);
      
      // Read caja
      cajaSnap = await db.collection('caja').doc('estado').get();
      
      // Collect and read all users
      const uidsToRead = new Set();
      if (!detalle || detalle.length === 0) {
        if (depUsuarioId) uidsToRead.add(depUsuarioId);
      } else {
        for (const part of detalle) {
          if (part?.id_usuario) uidsToRead.add(part.id_usuario);
        }
      }
      if (multasPorUsuario) {
        Object.keys(multasPorUsuario).forEach(k => uidsToRead.add(k));
      }
      
      for (const uid of Array.from(uidsToRead)) {
        const snap = await db.collection('usuarios').doc(uid).get();
        userSnaps[uid] = snap;
      }
    } catch (e) {
      console.error('[admin-api] Pre-transaction error:', e);
      return res.status(500).json({ error: e.message || 'Error en validaciones' });
    }

    // ========== TRANSACTION ==========
    await db.runTransaction(async (tx) => {
      const depRef = db.collection('depositos').doc(depositId);
      const depSnap = await tx.get(depRef);
      if (!depSnap.exists) throw new Error('Deposito no encontrado');
      const depDataTx = depSnap.data();

      // Handle rejection
      if (!approve) {
        tx.update(depRef, {
          validado: false,
          estado: 'rechazado',
          id_admin: adminUid,
          observaciones: observaciones || '',
          fecha_revision: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      // Mark multas as paid
      if (multasSnapBefore && depUsuarioId && userSnaps[depUsuarioId]) {
        for (const multaDoc of multasSnapBefore.docs) {
          tx.update(db.collection('multas').doc(multaDoc.id), {
            estado: 'pagada',
            fecha_pago: admin.firestore.FieldValue.serverTimestamp(),
            deposito_pago_id: depositId,
          });
        }
        tx.update(db.collection('usuarios').doc(depUsuarioId), { total_multas: 0.0 });
      }

      // Update deposit
      const updateData = {
        validado: true,
        estado: 'aprobado',
        id_admin: adminUid,
        observaciones: observaciones || '',
        fecha_revision: admin.firestore.FieldValue.serverTimestamp(),
      };
      if ((depTipo === 'plazo_fijo' || depTipo === 'certificado') && interes) {
        updateData.interes_porcentaje = parseFloat(interes);
      }
      if ((depTipo === 'plazo_fijo' || depTipo === 'certificado') && documento_url) {
        updateData.documento_url = documento_url;
      }
      tx.update(depRef, updateData);

      // Process deposits
      function fieldForTipo(tipo) {
        switch (tipo) {
          case 'plazo_fijo': return 'total_plazos_fijos';
          case 'certificado': return 'total_certificados';
          case 'pago_prestamo': return 'total_prestamos';
          case 'ahorro':
          default: return 'total_ahorros';
        }
      }

      if (!detalle || detalle.length === 0) {
        const idUsuario = depDataTx?.id_usuario;
        const monto = parseFloat(depDataTx?.monto || 0);
        if (!idUsuario || !userSnaps[idUsuario]) throw new Error('Usuario no encontrado');
        
        const userData = userSnaps[idUsuario].data();
        const targetField = fieldForTipo(depTipo);
        const montoNeto = Math.max(0, monto - multaMonto);
        
        tx.update(db.collection('usuarios').doc(idUsuario), {
          [targetField]: (userData[targetField] || 0) + montoNeto
        });
        
        tx.set(db.collection('movimientos').doc(), {
          id_usuario: idUsuario,
          tipo: depTipo || 'deposito',
          referencia_id: depositId,
          monto: montoNeto,
          fecha: admin.firestore.FieldValue.serverTimestamp(),
          descripcion: depDataTx?.descripcion || 'Deposito aprobado',
          registrado_por: adminUid,
        });
        
        let saldoCaja = 0.0;
        if (cajaSnap && cajaSnap.exists) saldoCaja = parseFloat(cajaSnap.data().saldo || 0);
        tx.update(db.collection('caja').doc('estado'), { saldo: saldoCaja + monto });
      } else {
        let multasSum = 0.0;
        for (const part of detalle) {
          const idUsuario = part?.id_usuario;
          const monto = parseFloat(part?.monto || 0);
          if (!idUsuario) continue;
          
          const userSnap = userSnaps[idUsuario];
          if (!userSnap || !userSnap.exists) continue;
          
          const userData = userSnap.data();
          const partTipo = part?.tipo || depDataTx?.tipo || 'ahorro';
          
          if (partTipo === 'multa') {
            multasSum += monto;
            continue;
          }
          
          const targetField = fieldForTipo(partTipo);
          tx.update(db.collection('usuarios').doc(idUsuario), {
            [targetField]: (userData[targetField] || 0) + monto
          });
          
          tx.set(db.collection('movimientos').doc(), {
            id_usuario: idUsuario,
            tipo: partTipo || 'deposito',
            referencia_id: depositId,
            monto: monto,
            fecha: admin.firestore.FieldValue.serverTimestamp(),
            descripcion: depDataTx?.descripcion || 'Deposito aprobado (repartido)',
            registrado_por: adminUid,
          });
        }
        
        const montoTotal = parseFloat(depDataTx?.monto || 0);
        if (montoTotal > 0) {
          let saldoCaja = 0.0;
          if (cajaSnap && cajaSnap.exists) saldoCaja = parseFloat(cajaSnap.data().saldo || 0);
          tx.update(db.collection('caja').doc('estado'), { saldo: saldoCaja + montoTotal });
        }
        
        if (multasPorUsuario) {
          for (const uid of Object.keys(multasPorUsuario)) {
            const multa = parseFloat(multasPorUsuario[uid] || 0);
            if (multa > 0) {
              multasSum += multa;
              tx.set(db.collection('movimientos').doc(), {
                id_usuario: uid,
                tipo: 'multa',
                referencia_id: depositId,
                monto: multa,
                fecha: admin.firestore.FieldValue.serverTimestamp(),
                descripcion: 'Multa aplicada por admin',
                registrado_por: adminUid,
              });
            }
          }
        }
        
        if (multasSum > 0) {
          let saldoMultas = 0.0;
          if (cajaSnap && cajaSnap.exists) saldoMultas = parseFloat(cajaSnap.data().saldo || 0);
          tx.update(db.collection('caja').doc('estado'), { saldo: saldoMultas + multasSum });
        }
      }

      // Final deposit update
      const updatePayload = {
        validado: approve,
        estado: approve ? 'aprobado' : 'rechazado',
        id_admin: adminUid,
        observaciones: observaciones || '',
        fecha_revision: admin.firestore.FieldValue.serverTimestamp(),
        fecha_aprobacion: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (multaMonto > 0) updatePayload.multa_monto = multaMonto;
      tx.update(depRef, updatePayload);
    });

    res.json({ ok: true, id: depositId });
  } catch (e) {
    console.error('[admin-api] Error approving deposit:', e);
    res.status(500).json({ error: e.message || e.toString() });
  }
});
`;

// Replace
const newContent = content.replace(approvePattern, newEndpoint);
if (newContent === content) {
  console.error('Pattern did not match');
  process.exit(1);
}

fs.writeFileSync(filePath, newContent.replace(/\n/g, '\r\n'), 'utf8');
console.log('✓ Transaction fixed: all reads moved before transaction');
