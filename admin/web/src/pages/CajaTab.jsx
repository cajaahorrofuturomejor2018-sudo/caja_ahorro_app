import React, { useEffect, useState } from 'react';
import { fetchCaja, updateCaja, setAuthToken } from '../utils/apiClient.js';

export default function CajaTab({ user }) {
  const [saldo, setSaldo] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [newSaldo, setNewSaldo] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (user?.token) {
      setAuthToken(user.token);
      load();
    }
  }, [user]);

  async function load() {
    setLoading(true);
    setError(null);
    const result = await fetchCaja();
    if (result.success) {
      setSaldo(result.data?.saldo ?? 0);
    } else {
      setError(result.error);
    }
    setLoading(false);
  }

  async function save() {
    if (newSaldo === '') {
      setError('Ingresa un monto');
      return;
    }

    setSaving(true);
    setError(null);
    const result = await updateCaja(parseFloat(newSaldo));
    setSaving(false);

    if (result.success) {
      setSuccess('Caja actualizada exitosamente');
      setTimeout(() => setSuccess(null), 3000);
      setNewSaldo('');
      load();
    } else {
      setError(result.error);
    }
  }

  return (
    <div>
      <h2>Caja - Control de Saldo</h2>

      {success && <div className="alert alert-success">{success}</div>}
      {error && <div className="alert alert-error">{error}</div>}

      <div className="card" style={{ marginTop: 16, padding: 16 }}>
        <h3>Saldo Actual</h3>
        {loading ? (
          <div className="alert alert-info">Cargando...</div>
        ) : (
          <div style={{ fontSize: 24, fontWeight: 'bold', color: '#1976d2', marginTop: 8 }}>
            S/ {saldo?.toFixed(2) ?? '0.00'}
          </div>
        )}
      </div>

      <div className="card" style={{ marginTop: 16, padding: 16 }}>
        <h3>Actualizar Saldo</h3>
        <div className="form-group">
          <label>Nuevo Saldo (S/) *</label>
          <input 
            type="number" 
            step="0.01" 
            min="0"
            value={newSaldo} 
            onChange={(e) => setNewSaldo(e.target.value)} 
            placeholder="0.00"
          />
        </div>
        <button 
          onClick={save} 
          disabled={saving}
          style={{ marginTop: 8 }}
        >
          {saving ? 'Guardando...' : 'Guardar Cambios'}
        </button>
      </div>
    </div>
  );
}
