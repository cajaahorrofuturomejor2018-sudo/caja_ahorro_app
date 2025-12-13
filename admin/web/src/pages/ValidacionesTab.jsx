import React, { useEffect, useState } from 'react';
import { apiGet, apiPost, setAuthToken } from '../utils/apiClient.js';
import { formatDate, formatCurrency } from '../utils/formatters.jsx';

export default function ValidacionesTab({ user }) {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [detail, setDetail] = useState(null);
  const [users, setUsers] = useState([]);
  const [selectedUsers, setSelectedUsers] = useState(new Set());
  const [approving, setApproving] = useState(null);

  useEffect(() => {
    if (user?.token) {
      setAuthToken(user.token);
      load();
    }
  }, [user]);

  async function load() {
    setLoading(true);
    setError(null);
    const [resDeposits, resUsers] = await Promise.all([
      apiGet('/deposits/pending'),
      apiGet('/users'),
    ]);
    
    if (resDeposits.success) {
      setItems(resDeposits.data || []);
    } else {
      setError(resDeposits.error);
    }
    
    if (resUsers.success) {
      setUsers(resUsers.data || []);
    }
    
    setLoading(false);
  }

  function previewDistribucion(monto) {
    const arr = Array.from(selectedUsers);
    if (arr.length === 0) return [];
    const totalCents = Math.round((monto * 100) || 0);
    const base = Math.floor(totalCents / arr.length);
    let rem = totalCents % arr.length;
    return arr.map((id) => {
      let cents = base;
      if (rem > 0) {
        cents += 1;
        rem -= 1;
      }
      return { id_usuario: id, monto: cents / 100.0 };
    });
  }

  async function approveDeposit(id, approve = true, detalle = null) {
    if (!window.confirm(`¿Estás seguro de ${approve ? 'aprobar' : 'rechazar'} este depósito?`)) return;

    setApproving(id);
    const result = await apiPost(`/api/deposits/${id}/approve`, { approve, detalleOverride: detalle });
    setApproving(null);

    if (result.success) {
      setSuccess('Operación exitosa');
      setTimeout(() => setSuccess(null), 3000);
      setDetail(null);
      load();
    } else {
      setError(result.error);
    }
  }

  return (
    <div>
      <h2>Validación de Depósitos Pendientes</h2>

      {success && <div className="alert alert-success">{success}</div>}
      {error && <div className="alert alert-error">{error}</div>}

      <div style={{ marginBottom: 16 }}>
        <button onClick={load} disabled={loading}>
          {loading ? 'Actualizando...' : 'Actualizar'}
        </button>
      </div>

      {loading ? (
        <div className="alert alert-info">Cargando depósitos pendientes...</div>
      ) : items.length === 0 ? (
        <div className="alert alert-success">No hay depósitos pendientes de validación</div>
      ) : (
        <table className="table table-hover">
          <thead>
            <tr>
              <th>Fecha</th>
              <th>Monto</th>
              <th>Tipo</th>
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {items.map(d => (
              <tr key={d.id}>
                <td>{formatDate(d.fecha_deposito || d.fecha_registro)}</td>
                <td>{formatCurrency(d.monto)}</td>
                <td>{d.tipo}</td>
                <td><strong>{d.estado || 'pendiente'}</strong></td>
                <td>
                  <button 
                    onClick={() => setDetail(d)}
                    style={{ padding: '4px 8px' }}
                  >
                    Ver Detalle
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {detail && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ width: 600, maxHeight: 'calc(100vh - 60px)', overflowY: 'auto' }}>
            <h3>Detalles del Depósito</h3>

            <div className="card" style={{ padding: 12, marginBottom: 12, background: '#f5f5f5' }}>
              <p><strong>ID:</strong> {detail.id}</p>
              <p><strong>Fecha:</strong> {formatDate(detail.fecha_deposito || detail.fecha_registro)}</p>
              <p><strong>Usuario:</strong> {detail.id_usuario}</p>
              <p><strong>Monto:</strong> {formatCurrency(detail.monto)}</p>
              <p><strong>Tipo:</strong> {detail.tipo}</p>
              <p><strong>Descripción:</strong> {detail.descripcion || '(sin comentario)'}</p>
            </div>

            <h4>Distribución Manual (opcional)</h4>
            <p style={{ fontSize: 12, color: '#666' }}>Selecciona usuarios para distribuir el monto entre ellos</p>

            <div style={{ maxHeight: 150, overflowY: 'auto', border: '1px solid #ddd', padding: 8, marginBottom: 12 }}>
              {users.length === 0 ? (
                <p style={{ margin: 0, color: '#666', fontSize: 12 }}>No hay usuarios disponibles</p>
              ) : (
                users.map(u => (
                  <label key={u.id} style={{ display: 'flex', alignItems: 'center', margin: '4px 0', cursor: 'pointer' }}>
                    <input
                      type="checkbox"
                      checked={selectedUsers.has(u.id)}
                      onChange={(e) => {
                        const s = new Set(selectedUsers);
                        if (e.target.checked) s.add(u.id);
                        else s.delete(u.id);
                        setSelectedUsers(s);
                      }}
                      style={{ marginRight: 8 }}
                    />
                    <span>{u.nombres || u.id}</span>
                  </label>
                ))
              )}
            </div>

            {selectedUsers.size > 0 && (
              <div className="card" style={{ padding: 12, marginBottom: 12, background: '#e3f2fd' }}>
                <strong style={{ display: 'block', marginBottom: 8 }}>Vista Previa de Distribución:</strong>
                <ul style={{ margin: 0, paddingLeft: 20 }}>
                  {previewDistribucion(parseFloat(detail.monto || 0)).map(p => (
                    <li key={p.id_usuario} style={{ fontSize: 12, marginBottom: 4 }}>
                      {p.id_usuario}: {formatCurrency(p.monto)}
                    </li>
                  ))}
                </ul>
              </div>
            )}

            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <button
                onClick={() => approveDeposit(detail.id, false)}
                disabled={approving === detail.id}
                style={{
                  background: approving === detail.id ? '#ccc' : '#d32f2f',
                  color: '#fff',
                  padding: '6px 12px'
                }}
              >
                {approving === detail.id ? 'Procesando...' : 'Rechazar'}
              </button>

              <button
                onClick={() => approveDeposit(detail.id, true, null)}
                disabled={approving === detail.id}
                style={{
                  background: approving === detail.id ? '#ccc' : '#388e3c',
                  color: '#fff',
                  padding: '6px 12px'
                }}
              >
                {approving === detail.id ? 'Procesando...' : 'Aprobar (Auto)'}
              </button>

              {selectedUsers.size > 0 && (
                <button
                  onClick={() => approveDeposit(detail.id, true, previewDistribucion(parseFloat(detail.monto || 0)))}
                  disabled={approving === detail.id}
                  style={{
                    background: approving === detail.id ? '#ccc' : '#1976d2',
                    color: '#fff',
                    padding: '6px 12px'
                  }}
                >
                  {approving === detail.id ? 'Procesando...' : 'Aprobar (Manual)'}
                </button>
              )}

              <button
                onClick={() => {
                  setDetail(null);
                  setSelectedUsers(new Set());
                }}
                className="btn btn-secondary"
              >
                Cerrar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
