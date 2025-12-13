import React, { useEffect, useState } from 'react';
import { fetchConfig, updateConfig, setAuthToken } from '../utils/apiClient.js';

export default function ConfiguracionTab({ user }) {
  const [cfg, setCfg] = useState({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (user?.token) {
      setAuthToken(user.token);
      loadCfg();
    }
  }, [user]);

  async function loadCfg() {
    setLoading(true);
    setError(null);
    const result = await fetchConfig();
    if (result.success) {
      setCfg(result.data || {});
    } else {
      setError(result.error);
    }
    setLoading(false);
  }

  async function save() {
    setSaving(true);
    setError(null);
    const result = await updateConfig(cfg);
    setSaving(false);

    if (result.success) {
      setSuccess('Configuración guardada exitosamente');
      setTimeout(() => setSuccess(null), 3000);
      loadCfg();
    } else {
      setError(result.error);
    }
  }

  return (
    <div>
      <h2>Configuración</h2>

      {success && <div className="alert alert-success">{success}</div>}
      {error && <div className="alert alert-error">{error}</div>}

      {loading ? (
        <div className="alert alert-info">Cargando configuración...</div>
      ) : (
        <div className="card" style={{ padding: 16 }}>
          <form onSubmit={(e) => { e.preventDefault(); save(); }}>
            <div className="form-group">
              <label>Enlace WhatsApp</label>
              <input
                type="url"
                value={cfg.whatsapp_link || cfg.whatsapp_group || ''}
                onChange={(e) => setCfg({ ...cfg, whatsapp_link: e.target.value })}
                placeholder="https://chat.whatsapp.com/..."
              />
            </div>

            <div className="form-group">
              <label>Correo de Soporte</label>
              <input
                type="email"
                value={cfg.support_email || ''}
                onChange={(e) => setCfg({ ...cfg, support_email: e.target.value })}
                placeholder="soporte@ejemplo.com"
              />
            </div>

            <div className="form-group">
              <label>Teléfono de Soporte</label>
              <input
                type="tel"
                value={cfg.support_phone || ''}
                onChange={(e) => setCfg({ ...cfg, support_phone: e.target.value })}
                placeholder="+51 900 000 000"
              />
            </div>

            <div className="form-group">
              <label>Descripción/Nombre de Organización</label>
              <textarea
                value={cfg.org_description || cfg.description || ''}
                onChange={(e) => setCfg({ ...cfg, org_description: e.target.value })}
                placeholder="Información sobre la organización"
                rows="3"
              />
            </div>

            <div style={{ marginTop: 16, display: 'flex', gap: 8 }}>
              <button type="submit" className="btn btn-primary" disabled={saving}>
                {saving ? 'Guardando...' : 'Guardar Configuración'}
              </button>
              <button type="button" onClick={loadCfg} className="btn btn-secondary">
                Recargar
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
