import React, { useEffect, useState } from 'react';
import { apiGet, setAuthToken } from '../utils/apiClient.js';

export default function AuditoriaTab({ user }) {
  const [movimientos, setMovimientos] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (user?.token) {
      setAuthToken(user.token);
      load();
    }
  }, [user]);

  async function load() {
    setLoading(true);
    setError(null);
    const result = await apiGet('/movimientos');
    if (result.success) {
      setMovimientos(result.data || []);
    } else {
      setError(result.error);
    }
    setLoading(false);
  }

  return (
    <div>
      <h2>Auditoría - Registro de Movimientos</h2>

      {error && <div className="alert alert-error">{error}</div>}

      <div style={{ marginBottom: 16 }}>
        <button onClick={load} disabled={loading}>
          {loading ? 'Actualizando...' : 'Actualizar'}
        </button>
      </div>

      {loading ? (
        <div className="alert alert-info">Cargando movimientos...</div>
      ) : movimientos.length === 0 ? (
        <div className="alert alert-warning">No hay movimientos registrados</div>
      ) : (
        <table className="table table-hover">
          <thead>
            <tr>
              <th>Fecha</th>
              <th>Tipo</th>
              <th>Usuario</th>
              <th>Monto</th>
              <th>Descripción</th>
            </tr>
          </thead>
          <tbody>
            {movimientos.map(renderMovimientoRow)}
          </tbody>
        </table>
      )}
    </div>
  );
}

function renderMovimientoRow(m) {
  let dateStr = '-';
  try {
    const f = m.fecha;
    if (f) {
      if (typeof f === 'string') dateStr = new Date(f).toLocaleString('es-ES');
      else if (typeof f.seconds === 'number') dateStr = new Date(f.seconds * 1000).toLocaleString('es-ES');
      else dateStr = new Date(f).toLocaleString('es-ES');
    }
  } catch (e) { /* ignore */ }
  
  return (
    <tr key={m.id}>
      <td style={{ fontSize: 12 }}>{dateStr}</td>
      <td><strong>{m.tipo}</strong></td>
      <td>{m.id_usuario}</td>
      <td>S/ {m.monto?.toFixed(2) || '0.00'}</td>
      <td style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
        {m.descripcion || '-'}
      </td>
    </tr>
  );
}
