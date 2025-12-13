import React, { useState } from 'react';
import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword } from 'firebase/auth';

import firebaseConfig from '../utils/firebaseConfig';

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

export default function Login({ onLogin }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const { user } = await signInWithEmailAndPassword(auth, email, password);
      const token = await user.getIdToken();
      onLogin({ email: user.email, uid: user.uid, token });
    } catch (err) {
      setError(err.message || 'Error en la autenticación');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.backgroundGradient}></div>
      
      <div style={styles.card}>
        {/* Header */}
        <div style={styles.header}>
          <div style={styles.logo}>💰</div>
          <h1 style={styles.title}>Caja de Ahorros</h1>
          <p style={styles.subtitle}>Panel Administrativo</p>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} style={styles.form}>
          {/* Email Input */}
          <div style={styles.inputGroup}>
            <label htmlFor="email" style={styles.label}>📧 Email</label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="tu@email.com"
              style={styles.input}
              required
              disabled={loading}
            />
          </div>

          {/* Password Input */}
          <div style={styles.inputGroup}>
            <label htmlFor="password" style={styles.label}>🔐 Contraseña</label>
            <div style={styles.passwordWrapper}>
              <input
                id="password"
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                style={styles.input}
                required
                disabled={loading}
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                style={styles.toggleButton}
                disabled={loading}
              >
                {showPassword ? '👁️' : '👁️‍🗨️'}
              </button>
            </div>
          </div>

          {/* Error Message */}
          {error && (
            <div style={styles.errorBox}>
              <span style={styles.errorIcon}>⚠️</span>
              <span>{error}</span>
            </div>
          )}

          {/* Submit Button */}
          <button
            type="submit"
            style={{
              ...styles.button,
              ...(loading ? styles.buttonLoading : {}),
            }}
            disabled={loading}
          >
            {loading ? '⏳ Ingresando...' : '🚀 Ingresar'}
          </button>
        </form>

        {/* Footer */}
        <div style={styles.footer}>
          <p style={styles.footerText}>
            © 2025 Caja de Ahorros. Sistema Administrativo Seguro.
          </p>
        </div>
      </div>
    </div>
  );
}

const styles = {
  container: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    minHeight: '100vh',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif',
    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    position: 'relative',
    overflow: 'hidden',
  },

  backgroundGradient: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    background: 'radial-gradient(circle at top right, rgba(102, 126, 234, 0.1) 0%, transparent 50%)',
    pointerEvents: 'none',
  },

  card: {
    background: 'rgba(255, 255, 255, 0.95)',
    backdropFilter: 'blur(10px)',
    borderRadius: '20px',
    boxShadow: '0 20px 60px rgba(0, 0, 0, 0.3)',
    padding: 'clamp(2rem, 5vw, 3.5rem)',
    width: '100%',
    maxWidth: '450px',
    zIndex: 1,
    border: '1px solid rgba(255, 255, 255, 0.18)',
    '@media (max-width: 768px)': {
      borderRadius: '15px',
      padding: 'clamp(1.5rem, 5vw, 2rem)',
      margin: '0 1rem',
    },
  },

  header: {
    textAlign: 'center',
    marginBottom: '2.5rem',
  },

  logo: {
    fontSize: 'clamp(2.5rem, 8vw, 3.5rem)',
    marginBottom: '1rem',
    animation: 'bounce 2s infinite',
  },

  title: {
    fontSize: 'clamp(1.8rem, 5vw, 2.2rem)',
    color: '#333',
    margin: '0.5rem 0',
    fontWeight: '700',
    letterSpacing: '-0.5px',
  },

  subtitle: {
    fontSize: 'clamp(0.9rem, 2vw, 1.05rem)',
    color: '#999',
    margin: '0.5rem 0 0',
    fontWeight: '400',
  },

  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: 'clamp(1.2rem, 3vw, 1.5rem)',
  },

  inputGroup: {
    display: 'flex',
    flexDirection: 'column',
    gap: '0.6rem',
  },

  label: {
    fontSize: 'clamp(0.85rem, 2vw, 0.95rem)',
    fontWeight: '600',
    color: '#444',
    marginBottom: '0.25rem',
  },

  input: {
    padding: 'clamp(0.75rem, 2vw, 1rem)',
    fontSize: 'clamp(0.9rem, 2vw, 1rem)',
    border: '2px solid #e0e0e0',
    borderRadius: '10px',
    outline: 'none',
    transition: 'all 0.3s ease',
    fontFamily: 'inherit',
    backgroundColor: '#f9f9f9',
    ':focus': {
      borderColor: '#667eea',
      boxShadow: '0 0 0 3px rgba(102, 126, 234, 0.1)',
      backgroundColor: '#fff',
    },
  },

  passwordWrapper: {
    position: 'relative',
    display: 'flex',
    alignItems: 'center',
  },

  toggleButton: {
    position: 'absolute',
    right: '0.75rem',
    background: 'none',
    border: 'none',
    fontSize: '1.2rem',
    cursor: 'pointer',
    padding: '0.5rem',
    color: '#999',
    transition: 'color 0.2s',
    ':hover': {
      color: '#667eea',
    },
  },

  errorBox: {
    display: 'flex',
    alignItems: 'center',
    gap: '0.75rem',
    padding: 'clamp(0.75rem, 2vw, 1rem)',
    backgroundColor: '#fee',
    border: '2px solid #f88',
    borderRadius: '10px',
    fontSize: 'clamp(0.85rem, 2vw, 0.95rem)',
    color: '#c33',
    fontWeight: '500',
    animation: 'slideIn 0.3s ease',
  },

  errorIcon: {
    fontSize: '1.2rem',
    flexShrink: 0,
  },

  button: {
    padding: 'clamp(0.9rem, 2vw, 1.1rem)',
    fontSize: 'clamp(0.95rem, 2vw, 1.05rem)',
    fontWeight: '600',
    color: '#fff',
    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    border: 'none',
    borderRadius: '10px',
    cursor: 'pointer',
    transition: 'all 0.3s ease',
    marginTop: '0.5rem',
    boxShadow: '0 4px 15px rgba(102, 126, 234, 0.4)',
    ':hover': {
      transform: 'translateY(-2px)',
      boxShadow: '0 6px 20px rgba(102, 126, 234, 0.6)',
    },
    ':active': {
      transform: 'translateY(0)',
    },
  },

  buttonLoading: {
    opacity: 0.7,
    cursor: 'not-allowed',
    transform: 'translateY(0)',
  },

  footer: {
    textAlign: 'center',
    marginTop: '2rem',
    paddingTop: '1.5rem',
    borderTop: '1px solid #eee',
  },

  footerText: {
    fontSize: 'clamp(0.75rem, 1.5vw, 0.85rem)',
    color: '#999',
    margin: 0,
  },
};

// Inyectar estilos globales para animaciones
const styleSheet = document.createElement('style');
styleSheet.textContent = `
  @keyframes bounce {
    0%, 100% { transform: translateY(0); }
    50% { transform: translateY(-10px); }
  }

  @keyframes slideIn {
    from {
      opacity: 0;
      transform: translateY(-10px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  input:focus {
    outline: none;
  }

  button:disabled {
    cursor: not-allowed;
    opacity: 0.7;
  }

  /* Responsivo */
  @media (max-width: 640px) {
    body {
      padding: 0.5rem;
    }
  }
`;
if (!document.head.querySelector('style[data-login-styles]')) {
  styleSheet.setAttribute('data-login-styles', 'true');
  document.head.appendChild(styleSheet);
}
