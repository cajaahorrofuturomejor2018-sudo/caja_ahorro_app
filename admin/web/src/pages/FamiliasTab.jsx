import React, { useEffect, useState } from 'react';
import { fetchFamilias, createFamilia, setAuthToken } from '../utils/apiClient.js';

export default function FamiliasTab({ user }) {
  const [familias, setFamilias] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [showNew, setShowNew] = useState(false);
  const [name, setName] = useState('');
  const [creating, setCreating] = useState(false);

  useEffect(() => {
    if (user?.token) {
      setAuthToken(user.token);
      load();
    }
  }, [user]);

  async function load() {
    setLoading(true);
    setError(null);
    const result = await fetchFamilias();
    if (result.success) {
      setFamilias(result.data || []);
    } else {
      setError(result.error);
    }
    setLoading(false);
  }

  async function crear(e) {
    e.preventDefault();
    if (!name.trim()) {
      setError('Ingresa el nombre de la familia');
      return;
    }

    setCreating(true);
    setError(null);
    const result = await createFamilia({ nombre: name });
    setCreating(false);

    if (result.success) {
      setSuccess('Familia creada exitosamente');
      setTimeout(() => setSuccess(null), 3000);
      setShowNew(false);
      setName('');
      load();
    } else {
      setError(result.error);
    }
  }

  return (
    <div>
      <h2>Familias</h2>

      {success && <div className="alert alert-success">{success}</div>}
      {error && <div className="alert alert-error">{error}</div>}

      <div style={{ marginBottom: 16 }}>
        <button onClick={() => {
          setShowNew(true);
          setError(null);
        }}>+ Crear Familia</button>
      </div>

      {loading ? (
        <div className="alert alert-info">Cargando familias...</div>
      ) : familias.length === 0 ? (
        <div className="alert alert-warning">No hay familias registradas</div>
      ) : (
        <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 16 }}>
          {familias.map(f => (
            <div key={f.id} className="card" style={{ padding: 16 }}>
              <h4 style={{ margin: '0 0 8px 0' }}>{f.nombre || f.id}</h4>
              <p style={{ margin: 0, fontSize: 12, color: '#666' }}>ID: {f.id}</p>
            </div>
          ))}
        </div>
      )}

      {showNew && (
        <div className="modal-overlay">
          <form onSubmit={crear} className="modal-content" style={{ width: 400 }}>
            <h3>Crear Nueva Familia</h3>

            <div className="form-group">
              <label>Nombre de la Familia *</label>
              <input
                required
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Ej: Familia García"
              />
            </div>

            <div style={{ marginTop: 16, display: 'flex', gap: 8 }}>
              <button type="submit" className="btn btn-primary" disabled={creating}>
                {creating ? 'Creando...' : 'Crear Familia'}
              </button>
              <button
                type="button"
                onClick={() => {
                  setShowNew(false);
                  setError(null);
                }}
                className="btn btn-secondary"
              >
                Cancelar
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
