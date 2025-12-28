const fs = require('fs');
const file = 'server.js';
let c = fs.readFileSync(file, 'utf8');

const p1 = `    res.json({ ok: true, id: uid });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message || e.toString() });
  }
});

// Update user role`;

const p2 = `    res.json({ ok: true, id: uid });
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

// Update user role`;

if (c.includes(p1)) {
  c = c.replace(p1, p2);
  fs.writeFileSync(file, c, 'utf8');
  console.log('✓ Patched successfully!');
} else {
  console.error('✗ Pattern not found, searching for alternatives...');
  if (c.includes('// Update user role')) {
    console.log('✓ Found "// Update user role" comment');
  }
  if (c.includes('console.error(e);')) {
    console.log('✓ Found old error handler');
  }
  process.exit(1);
}
