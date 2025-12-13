import React, { useEffect, useState } from 'react';
import { fetchUsers, createUser, updateUserRole, updateUserEstado, setAuthToken } from '../utils/apiClient.js';
import { formatDate, getEstadoBadge } from '../utils/formatters.jsx';

export default function UsuariosTab({ user }) {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [showNew, setShowNew] = useState(false);
  const [updating, setUpdating] = useState(null);
  const [form, setForm] = useState({ nombre: '', correo: '', password: '', rol: 'cliente', telefono: '', direccion: '', estado: 'activo' });

  useEffect(() => {
    if (user?.token) {
      setAuthToken(user.token);
      load();
    }
  }, [user]);

  async function load() {
    setLoading(true);
    setError(null);
    const result = await fetchUsers();
    if (result.success) {
      setUsers(result.data || []);
    } else {
      setError(result.error);
    }
    setLoading(false);
  }

  async function crearUsuario(e) {
    e.preventDefault();
    setError(null);
    
    if (!form.nombre || !form.correo || !form.password) {
      setError('Ingresa Nombre, Correo y Contraseña');
      return;
    }
    
    const result = await createUser(form);
    if (result.success) {
      setSuccess('Usuario creado exitosamente');
      setTimeout(() => setSuccess(null), 3000);
      setShowNew(false);
      setForm({ nombre: '', correo: '', password: '', rol: 'cliente', telefono: '', direccion: '', estado: 'activo' });
      load();
    } else {
      setError(result.error);
    }
  }

  async function setRole(uid, role) {
    setUpdating(uid);
    const result = await updateUserRole(uid, role);
    setUpdating(null);
    
    if (result.success) {
      setSuccess('Rol actualizado');
      setTimeout(() => setSuccess(null), 2000);
      load();
    } else {
      setError(result.error);
    }
  }

  async function setEstado(uid, estado) {
    setUpdating(uid);
    const result = await updateUserEstado(uid, estado);
    setUpdating(null);
    
    if (result.success) {
      setSuccess('Estado actualizado');
      setTimeout(() => setSuccess(null), 2000);
      load();
    } else {
      setError(result.error);
    }
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
        <h2 style={{ margin: 0, border: 'none', padding: 0 }}>👥 Usuarios</h2>
        <button onClick={() => setShowNew(true)} style={{ background: 'var(--success-color)' }}>
          + Crear Usuario
        </button>
      </div>

      {success && <div className="success">{success}</div>}
      {error && <div className="error">{error}</div>}

      {loading ? (
        <div className="info">⏳ Cargando usuarios...</div>
      ) : users.length === 0 ? (
        <div className="warning">⚠️ No hay usuarios registrados</div>
      ) : (
        <div style={{ overflowX: 'auto' }}>
          <table>
            <thead>
              <tr>
                <th>Nombre</th>
                <th>Correo</th>
                <th>Rol</th>
                <th>Estado</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              {users.map(u => (
                <tr key={u.id}>
                  <td style={{ fontWeight: '600' }}>{u.nombres || '-'}</td>
                  <td style={{ fontSize: '0.9rem', color: 'var(--text-secondary)' }}>{u.correo || '-'}</td>
                  <td>
                    <select 
                      value={u.rol || 'cliente'} 
                      onChange={(e) => setRole(u.id, e.target.value)}
                      disabled={updating === u.id}
                      style={{ padding: '6px 10px', fontSize: '0.9rem' }}
                    >
                      <option value="cliente">👤 Cliente</option>
                      <option value="admin">🔐 Admin</option>
                      <option value="gestor">📊 Gestor</option>
                    </select>
                  </td>
                  <td>
                    <select 
                      value={u.estado || 'activo'} 
                      onChange={(e) => setEstado(u.id, e.target.value)}
                      disabled={updating === u.id}
                      style={{ padding: '6px 10px', fontSize: '0.9rem' }}
                    >
                      <option value="activo">✅ Activo</option>
                      <option value="inactivo">⛔ Inactivo</option>
                    </select>
                  </td>
                  <td>
                    <button 
                      onClick={() => {
                        navigator.clipboard?.writeText(u.id);
                        setSuccess('UID copiado');
                        setTimeout(() => setSuccess(null), 2000);
                      }}
                      style={{ padding: '6px 12px', fontSize: '0.85rem', background: '#6b7280' }}
                    >
                      📋 Copiar UID
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {showNew && (
        <div className="modal-overlay">
          <form onSubmit={crearUsuario} className="modal-content" style={{ width: 450 }}>
            <h3>Crear Nuevo Usuario</h3>

            <div className="form-group">
              <label>Nombre *</label>
              <input 
                required 
                type="text"
                value={form.nombre} 
                onChange={(e) => setForm({ ...form, nombre: e.target.value })} 
              />
            </div>

            <div className="form-group">
              <label>Correo *</label>
              <input 
                required 
                type="email" 
                value={form.correo} 
                onChange={(e) => setForm({ ...form, correo: e.target.value })} 
              />
            </div>

            <div className="form-group">
              <label>Contraseña *</label>
              <input 
                required 
                type="password" 
                value={form.password} 
                onChange={(e) => setForm({ ...form, password: e.target.value })} 
              />
            </div>

            <div className="form-group">
              <label>Rol</label>
              <select 
                value={form.rol} 
                onChange={(e) => setForm({ ...form, rol: e.target.value })}
              >
                <option value="cliente">Cliente</option>
                <option value="admin">Admin</option>
                <option value="gestor">Gestor</option>
              </select>
            </div>

            <div className="form-group">
              <label>Teléfono</label>
              <input 
                type="tel"
                value={form.telefono} 
                onChange={(e) => setForm({ ...form, telefono: e.target.value })} 
              />
            </div>

            <div className="form-group">
              <label>Dirección</label>
              <input 
                type="text"
                value={form.direccion} 
                onChange={(e) => setForm({ ...form, direccion: e.target.value })} 
              />
            </div>

            <div style={{ marginTop: 16, display: 'flex', gap: 8 }}>
              <button type="submit" className="btn btn-primary">Crear Usuario</button>
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
