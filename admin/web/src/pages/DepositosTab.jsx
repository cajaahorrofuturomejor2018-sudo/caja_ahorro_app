import React, { useEffect, useState } from 'react';
import { fetchDeposits, approveDeposit, addAporte, deleteDeposit, setAuthToken } from '../utils/apiClient.js';
import { formatDate, formatCurrency, getEstadoBadge } from '../utils/formatters.jsx';

export default function DepositosTab({ user }) {
  const [deposits, setDeposits] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [showNew, setShowNew] = useState(false);
  const [approving, setApproving] = useState(null);
  const [form, setForm] = useState({ idUsuario: '', tipo: 'aporte', monto: '', descripcion: '' });

  useEffect(() => {
    if (user?.token) {
      setAuthToken(user.token);
      load();
    }
  }, [user]);

  async function load() {
    setLoading(true);
    setError(null);
    const result = await fetchDeposits();
    if (result.success) {
      // Deduplicar: mantener solo la primera ocurrencia de cada depósito
      const data = result.data || [];
      const seen = new Set();
      const unique = data.filter(d => {
        if (seen.has(d.id)) return false;
        seen.add(d.id);
        return true;
      });
      setDeposits(unique);
    } else {
      setError(result.error);
    }
    setLoading(false);
  }

  async function approve(id, approve = true) {
    if (!window.confirm(`¿Estás seguro de ${approve ? 'aprobar' : 'rechazar'} este depósito?`)) return;
    
    setApproving(id);
    const result = await approveDeposit(id, approve);
    setApproving(null);
    
    if (result.success) {
      setSuccess('Operación realizada exitosamente');
      setTimeout(() => setSuccess(null), 3000);
      load();
    } else {
      setError(result.error);
    }
  }

  async function eliminar(id) {
    if (!window.confirm('¿Eliminar este depósito? Esto lo marcará como eliminado.')) return;
    setApproving(id);
    const result = await deleteDeposit(id, 'Eliminado desde panel admin');
    setApproving(null);
    if (result.success) {
      setSuccess('Depósito eliminado');
      setTimeout(() => setSuccess(null), 3000);
      load();
    } else {
      setError(result.error);
    }
  }

  async function crearAporte(e) {
    e.preventDefault();
    setError(null);
    
    if (!form.idUsuario || !form.monto) {
      setError('Ingresa ID Usuario y Monto');
      return;
    }
    
    const result = await addAporte({
      idUsuario: form.idUsuario,
      tipo: form.tipo,
      monto: parseFloat(form.monto),
      descripcion: form.descripcion
    });
    
    if (result.success) {
      setSuccess('Aporte creado exitosamente');
      setTimeout(() => setSuccess(null), 3000);
      setShowNew(false);
      setForm({ idUsuario: '', tipo: 'aporte', monto: '', descripcion: '' });
      load();
    } else {
      setError(result.error);
    }
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
        <h2 style={{ margin: 0, border: 'none', padding: 0 }}>💰 Depósitos</h2>
        <button onClick={() => setShowNew(true)} style={{ background: 'var(--success-color)' }}>
          + Agregar Depósito
        </button>
      </div>
      
      {success && <div className="success">{success}</div>}
      {error && <div className="error">{error}</div>}
      
      {loading ? (
        <div className="info">⏳ Cargando depósitos...</div>
      ) : deposits.length === 0 ? (
        <div className="warning">⚠️ No hay depósitos registrados</div>
      ) : (
        <div style={{ overflowX: 'auto' }}>
          <table>
            <thead>
              <tr>
                <th>Usuario</th>
                <th>Fecha</th>
                <th>Monto</th>
                <th>Tipo</th>
                <th>Estado</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              {deposits.map(d => (
                <tr key={d.id}>
                  <td style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                    {d.id_usuario?.substring(0, 8) || '-'}
                  </td>
                  <td>{formatDate(d.fecha_deposito)}</td>
                  <td style={{ fontWeight: 'bold', color: 'var(--success-color)' }}>
                    {formatCurrency(d.monto || d.monto_solicitado)}
                  </td>
                  <td>
                    <span style={{
                      background: '#e0f2fe',
                      color: '#0369a1',
                      padding: '4px 8px',
                      borderRadius: '6px',
                      fontSize: '0.85rem'
                    }}>
                      {d.tipo || 'ahorro'}
                    </span>
                  </td>
                  <td>{getEstadoBadge(d.estado || (d.validado ? 'aprobado' : 'pendiente'))}</td>
                  <td>
                    <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                      {d.estado !== 'aprobado' && d.estado !== 'eliminado' && (
                        <>
                          <button 
                            onClick={() => approve(d.id, true)} 
                            disabled={approving === d.id}
                            style={{ 
                              background: approving === d.id ? '#ccc' : 'var(--success-color)',
                              color: '#fff',
                              padding: '6px 12px',
                              fontSize: '0.85rem'
                            }}
                          >
                            {approving === d.id ? '⏳' : '✓ Aprobar'}
                          </button>
                          <button 
                            onClick={() => approve(d.id, false)} 
                            disabled={approving === d.id}
                            style={{ 
                              background: approving === d.id ? '#ccc' : 'var(--danger-color)',
                              color: '#fff',
                              padding: '6px 12px',
                              fontSize: '0.85rem'
                            }}
                          >
                            {approving === d.id ? '⏳' : '✗ Rechazar'}
                          </button>
                        </>
                      )}
                      {d.estado !== 'eliminado' && (
                        <button
                          onClick={() => eliminar(d.id)}
                          disabled={approving === d.id}
                          style={{ 
                            background: '#757575', 
                            color: '#fff', 
                            padding: '6px 12px',
                            fontSize: '0.85rem'
                          }}
                        >
                          {approving === d.id ? '⏳' : '🗑️'}
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}


      {showNew && (
        <div className="modal-overlay" onClick={() => setShowNew(false)}>
          <form onSubmit={crearAporte} className="modal-content" onClick={(e) => e.stopPropagation()}>
            <h3>✨ Crear Nuevo Aporte</h3>
            
            <div className="form-group">
              <label>ID Usuario (UID) *</label>
              <input 
                required 
                type="text"
                value={form.idUsuario} 
                onChange={(e) => setForm({ ...form, idUsuario: e.target.value })} 
                placeholder="Ej: ZaCflTMfMtcq..."
              />
            </div>

            <div className="form-group">
              <label>Tipo *</label>
              <select 
                value={form.tipo} 
                onChange={(e) => setForm({ ...form, tipo: e.target.value })}
              >
                <option value="aporte">Aporte Regular</option>
                <option value="aporte_extra">Aporte Extra</option>
                <option value="certificado">Certificado</option>
                <option value="retiro">Retiro</option>
              </select>
            </div>

            <div className="form-group">
              <label>Monto (S/) *</label>
              <input 
                required 
                type="number" 
                step="0.01" 
                min="0"
                value={form.monto} 
                onChange={(e) => setForm({ ...form, monto: e.target.value })} 
                placeholder="0.00"
              />
            </div>

            <div className="form-group">
              <label>Descripción</label>
              <input 
                type="text"
                value={form.descripcion} 
                onChange={(e) => setForm({ ...form, descripcion: e.target.value })} 
                placeholder="Opcional"
              />
            </div>

            <div style={{ marginTop: '1.5rem', display: 'flex', gap: '0.5rem' }}>
              <button type="submit" style={{ flex: 1, background: 'var(--success-color)' }}>
                ✓ Crear Aporte
              </button>
              <button 
                type="button" 
                onClick={() => {
                  setShowNew(false);
                  setError(null);
                }} 
                style={{ flex: 1, background: '#757575' }}
              >
                ✗ Cancelar
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
