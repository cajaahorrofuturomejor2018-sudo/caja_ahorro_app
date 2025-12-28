const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'admin', 'api', 'server.js');
let content = fs.readFileSync(filePath, 'utf8');

// El error es que hay await tx.get() después de tx.update() y tx.set()
// Necesitamos reorganizar la transacción para que TODAS las lecturas sean ANTES

// Buscar y reemplazar la sección de la transacción
const transactionStart = content.indexOf('await db.runTransaction(async (tx) => {');
const transactionEnd = content.indexOf('res.json({', transactionStart) - 20;

if (transactionStart === -1) {
  console.error('No se encontró la transacción');
  process.exit(1);
}

// Extraer la transacción actual
const oldTransaction = content.substring(transactionStart, transactionEnd);

// Nueva transacción con todas las lecturas al principio
const newTransaction = `await db.runTransaction(async (tx) => {
      // ============================================
      // FASE 1: LEER TODOS LOS DOCUMENTOS NECESARIOS
      // ============================================
      const depRef = db.collection('depositos').doc(depositId);
      const depSnap = await tx.get(depRef);
      if (!depSnap.exists) throw new Error('Depósito no encontrado');
      const depData = depSnap.data();
      const depTipo = depData?.tipo || 'ahorro';
      const depUsuarioId = depData?.id_usuario;
      
      // Pre-collect all UIDs that will need to be read
      const uidsToRead = new Set();
      const detalle = detalleOverride || parseDetalle(depData?.detalle_por_usuario);
      if (!detalle || detalle.length === 0) {
        if (depUsuarioId) uidsToRead.add(depUsuarioId);
      } else {
        for (const part of detalle) {
          if (part?.id_usuario) uidsToRead.add(part.id_usuario);
        }
      }
      if (depUsuarioId && (depTipo === 'multa' || multaMonto > 0)) {
        uidsToRead.add(depUsuarioId);
      }
      if (multasPorUsuario) {
        Object.keys(multasPorUsuario).forEach(k => uidsToRead.add(k));
      }
      
      // Read all user documents
      const userSnaps = {};
      for (const uid of Array.from(uidsToRead)) {
        const snap = await tx.get(db.collection('usuarios').doc(uid));
        userSnaps[uid] = snap;
      }
      
      // Read caja state (may be needed for updates)
      const cajaRef = db.collection('caja').doc('estado');
      const cajaSnap = await tx.get(cajaRef);
      let currentCaja = 0.0;
      if (cajaSnap.exists) currentCaja = parseFloat(cajaSnap.data().saldo || 0);
      
      // ============================================
      // FASE 2: LÓGICA DE APROBACIÓN/RECHAZO
      // ============================================
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
      
      // Handle multa deposits: mark pending multas as paid
      if (depTipo === 'multa' && depUsuarioId) {
        // Since we can't query inside transaction, we handled this outside
        // Just update user's total_multas to 0
        const userRef = db.collection('usuarios').doc(depUsuarioId);
        const userSnap = userSnaps[depUsuarioId];
        if (userSnap && userSnap.exists) {
          tx.update(userRef, { total_multas: 0.0 });
        }
      }
      
      // Get configuration for penalty and parametros
      const config = await getConfiguracion();
      const multaMonto = computePenalty(depData, config);
      
      // Validate plazo_fijo/certificado requirements
      if (approve && (depTipo === 'plazo_fijo' || depTipo === 'certificado')) {
        if (!documento_url && !depData?.documento_url) {
          throw new Error('Debe cargar el documento PDF antes de aprobar un ' + depTipo);
        }
        if (!interes && !depData?.interes_porcentaje) {
          throw new Error('Debe ingresar el interés % antes de aprobar un ' + depTipo);
        }
      }
      
      // Build update data for deposit
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
      
      // ============================================
      // FASE 3: PROCESAR DETALLES Y DISTRIBUCIONES
      // ============================================
      let montoSobrante = 0.0;
      if (detalle && detalle.length > 0) {
        const montoTotal = parseFloat(depData?.monto || 0);
        let sumDetalle = 0.0;
        for (const p of detalle) { sumDetalle += parseFloat(p.monto || p['monto'] || 0); }
        if (Math.round(sumDetalle * 100) > Math.round(montoTotal * 100)) {
          throw new Error('La suma del detalle excede el monto del depósito');
        }
        montoSobrante = montoTotal - sumDetalle;
      }
      
      // Process distribution if no detalle (simple case)
      if (!detalle || detalle.length === 0) {
        const idUsuario = depData?.id_usuario;
        const monto = parseFloat(depData?.monto || 0);
        if (!idUsuario) throw new Error('Depósito sin id_usuario');
        
        const userSnap = userSnaps[idUsuario];
        if (!userSnap || !userSnap.exists) throw new Error('Usuario del depósito no encontrado');
        const userData = userSnap.data();
        
        // Auto-monthly reparto for ahorro >= \$25
        if (depTipo === 'ahorro' && monto >= 25) {
          const repartoResult = splitMonthlyDeposit(monto, depData?.fecha_deposito_detectada, config);
          if (repartoResult && repartoResult.detalle) {
            const newDetalle = repartoResult.detalle.map(item => ({
              id_usuario: idUsuario,
              monto: item.monto,
              mes: item.mes,
              año: item.año
            }));
            tx.update(depRef, {
              detalle_auto_generado: true,
              detalle_por_usuario: JSON.stringify(newDetalle),
              meses_cubiertos: repartoResult.mesesCubiertos,
              sobrante: repartoResult.sobrante
            });
          }
        }
        
        // Simple accrual if no monthly reparto
        function fieldForTipo(tipo) {
          switch (tipo) {
            case 'plazo_fijo': return 'total_plazos_fijos';
            case 'certificado': return 'total_certificados';
            case 'pago_prestamo': return 'total_prestamos';
            case 'ahorro':
            default: return 'total_ahorros';
          }
        }
        const targetField = fieldForTipo(depTipo);
        const montoMulta = parseFloat(multaMonto || 0);
        const montoUsuarioNeto = Math.max(0, monto - montoMulta);
        
        // Update 2026 advance
        try {
          const params2026 = loadParametros2026();
          const anioCfg = parseInt(params2026?.anio || 2026, 10);
          const diaLimite = parseInt(params2026?.dia_limite_mensual || 10, 10);
          const fechaDep = depData?.fecha_deposito_detectada || depData?.fecha_deposito || new Date();
          const jsFechaDep = toJsDate(fechaDep);
          const yearDep = jsFechaDep.getFullYear();
          const monthIdx = jsFechaDep.getMonth() + 1;
          const dayIdx = jsFechaDep.getDate();
          if (yearDep === anioCfg && (depTipo === 'ahorro' || depTipo === 'deposito')) {
            const aporteMensual = aporteMensualForUser(userData, params2026);
            const objetivoAcumuladoMes = aporteMensual * monthIdx;
            const avanceActual = parseFloat(userData?.avance_anual_2026 || 0);
            const exentoPorAvance = !!(params2026?.reglas?.exencion_multa_si_adelantado) && (avanceActual >= objetivoAcumuladoMes);
            const exentoPorMesCumplido = !!(params2026?.reglas?.exencion_multa_si_avance_mes_cumplido) && (dayIdx <= diaLimite) && ((avanceActual + montoUsuarioNeto) >= objetivoAcumuladoMes);
            if (exentoPorAvance || exentoPorMesCumplido) {
              tx.update(depRef, { exento_multa: true });
            }
            const nuevoAvance = avanceActual + montoUsuarioNeto;
            const objetivoAnual = objetivoAnualForUser(userData, params2026);
            tx.update(db.collection('usuarios').doc(idUsuario), {
              avance_anual_2026: nuevoAvance,
              objetivo_anual_2026: userData?.objetivo_anual_2026 || objetivoAnual,
            });
          }
        } catch (e) { /* noop */ }
        
        const current = (userData[targetField] || 0) + montoUsuarioNeto;
        tx.update(db.collection('usuarios').doc(idUsuario), { [targetField]: current });
        tx.set(db.collection('movimientos').doc(), {
          id_usuario: idUsuario,
          tipo: depTipo || 'deposito',
          referencia_id: depositId,
          monto: montoUsuarioNeto,
          fecha: admin.firestore.FieldValue.serverTimestamp(),
          descripcion: depData?.descripcion || 'Depósito aprobado',
          registrado_por: adminUid,
        });
        
        // Update caja with full deposit amount
        const nuevoSaldoCaja = currentCaja + monto;
        tx.update(cajaRef, { saldo: nuevoSaldoCaja });
        
        // Penalty
        if (multaMonto > 0) {
          const nuevoSaldoMulta = currentCaja + multaMonto;
          tx.update(cajaRef, { saldo: nuevoSaldoMulta });
          tx.set(db.collection('movimientos').doc(), {
            id_usuario: depData?.id_usuario || '',
            tipo: 'multa',
            referencia_id: depositId,
            monto: multaMonto,
            fecha: admin.firestore.FieldValue.serverTimestamp(),
            descripcion: 'Multa por depósito tardío',
            registrado_por: adminUid,
          });
        }
      } else {
        // Process with detalle distribution
        let multasSum = 0.0;
        for (const part of detalle) {
          const idUsuario = part?.id_usuario;
          const monto = parseFloat(part?.monto || 0);
          if (!idUsuario) continue;
          
          const userSnap = userSnaps[idUsuario];
          if (!userSnap || !userSnap.exists) continue;
          const userData = userSnap.data();
          const partTipo = part?.tipo || depData?.tipo || 'ahorro';
          
          if (partTipo === 'multa') {
            multasSum += monto;
            continue;
          }
          
          function fieldForTipo(tipo) {
            switch (tipo) {
              case 'plazo_fijo': return 'total_plazos_fijos';
              case 'certificado': return 'total_certificados';
              case 'pago_prestamo': return 'total_prestamos';
              case 'ahorro':
              default: return 'total_ahorros';
            }
          }
          const targetField = fieldForTipo(partTipo);
          const current = (userData[targetField] || 0) + monto;
          
          try {
            const params2026 = loadParametros2026();
            const anioCfg = parseInt(params2026?.anio || 2026, 10);
            const fechaDep = depData?.fecha_deposito_detectada || depData?.fecha_deposito || new Date();
            const jsFechaDep = toJsDate(fechaDep);
            if (jsFechaDep.getFullYear() === anioCfg && (partTipo === 'ahorro' || partTipo === 'deposito')) {
              const avanceActual = parseFloat(userData?.avance_anual_2026 || 0);
              const nuevoAvance = avanceActual + parseFloat(monto || 0);
              const objetivoAnual = objetivoAnualForUser(userData, params2026);
              tx.update(db.collection('usuarios').doc(idUsuario), {
                avance_anual_2026: nuevoAvance,
                objetivo_anual_2026: userData?.objetivo_anual_2026 || objetivoAnual,
              });
            }
          } catch (e) { /* noop */ }
          
          tx.update(db.collection('usuarios').doc(idUsuario), { [targetField]: current });
          tx.set(db.collection('movimientos').doc(), {
            id_usuario: idUsuario,
            tipo: partTipo || 'deposito',
            referencia_id: depositId,
            monto: monto,
            fecha: admin.firestore.FieldValue.serverTimestamp(),
            descripcion: depData?.descripcion || 'Depósito aprobado (repartido)',
            registrado_por: adminUid,
          });
        }
        
        // Update caja with full amount
        const montoTotalDeposito = parseFloat(depData?.monto || 0);
        if (montoTotalDeposito > 0) {
          tx.update(cajaRef, { saldo: currentCaja + montoTotalDeposito });
        }
        
        // Add custom multas
        if (multasPorUsuario) {
          for (const uid of Object.keys(multasPorUsuario)) {
            const multa = parseFloat(multasPorUsuario[uid] || 0);
            if (multa <= 0) continue;
            multasSum += multa;
            tx.set(db.collection('movimientos').doc(), {
              id_usuario: uid,
              tipo: 'multa',
              referencia_id: depositId,
              monto: multa,
              fecha: admin.firestore.FieldValue.serverTimestamp(),
              descripcion: 'Multa aplicada por admin durante revisión',
              registrado_por: adminUid,
            });
          }
        }
        
        if (multaMonto > 0) {
          multasSum += multaMonto;
          const autorId = depData?.id_usuario || '';
          tx.set(db.collection('movimientos').doc(), {
            id_usuario: autorId,
            tipo: 'multa',
            referencia_id: depositId,
            monto: multaMonto,
            fecha: admin.firestore.FieldValue.serverTimestamp(),
            descripcion: 'Multa por depósito tardío',
            registrado_por: adminUid,
          });
        }
        
        if (multasSum > 0) {
          tx.update(cajaRef, { saldo: currentCaja + multasSum });
        }
      }
      
      // Final update to deposit
      const updatePayload = {
        validado: approve,
        estado: approve ? 'aprobado' : 'rechazado',
        id_admin: adminUid,
        observaciones: observaciones || '',
        fecha_revision: admin.firestore.FieldValue.serverTimestamp(),
        fecha_aprobacion: approve ? admin.firestore.FieldValue.serverTimestamp() : admin.firestore.FieldValue.serverTimestamp(),
      };
      if (multaMonto > 0) updatePayload.multa_monto = multaMonto;
      if (montoSobrante > 0) updatePayload.monto_sobrante = montoSobrante;
      tx.update(depRef, updatePayload);
    });`;

// Replace the transaction
const beforeTransaction = content.substring(0, transactionStart);
const afterTransaction = content.substring(transactionEnd);

const newContent = beforeTransaction + newTransaction + afterTransaction;

// Write the file with UTF-8 and Windows line endings
fs.writeFileSync(filePath, newContent.replace(/\n/g, '\r\n'), { encoding: 'utf8' });
console.log('✓ Transacción corregida: todas las lecturas ahora están al principio');
