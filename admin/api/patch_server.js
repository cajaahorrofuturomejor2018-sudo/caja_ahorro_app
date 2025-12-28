const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'server.js');
let content = fs.readFileSync(filePath, 'utf8');

// Find and replace the /api/users error handler
const oldPattern = `    res.json({ ok: true, id: uid });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message || e.toString() });
  }
});

// Update user role`;

const newPattern = `    res.json({ ok: true, id: uid });
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

// Update user role`;

if (content.includes(oldPattern)) {
  content = content.replace(oldPattern, newPattern);
  fs.writeFileSync(filePath, content, 'utf8');
  console.log('✓ server.js patched successfully');
} else {
  console.error('✗ Could not find pattern to patch');
  process.exit(1);
}
