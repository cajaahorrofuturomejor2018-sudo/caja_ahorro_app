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
  const [showApproveModal, setShowApproveModal] = useState(null);
  const [approveForm, setApproveForm] = useState({
    interes: '',
    observaciones: '',
    pdfFile: null,
    uploadingPdf: false,
    pdfUrl: ''
  });
  const [showVoucherModal, setShowVoucherModal] = useState(null);
  const [downloadingReport, setDownloadingReport] = useState(false);

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

  async function downloadReporteUsuarios() {
    try {
      setDownloadingReport(true);
      const base = import.meta.env.VITE_API_URL || 'http://localhost:8080';
      // Fix: avoid /api/api/ duplication when VITE_API_URL is '/api'
      const reportUrl = base.endsWith('/api') 
        ? `${base}/reportes/usuarios` 
        : `${base}/api/reportes/usuarios`;
      const resp = await fetch(reportUrl, {
        headers: { Authorization: `Bearer ${user.token}` }
      });
      if (!resp.ok) throw new Error('Error generando reporte');
      const blob = await resp.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'reporte_usuarios.pdf';
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);
      setSuccess('Reporte descargado');
      setTimeout(() => setSuccess(null), 2500);
    } catch (e) {
      setError(e.message || 'Error al descargar el reporte');
    } finally {
      setDownloadingReport(false);
    }
  }

  function openApproveModal(deposito) {
    setShowApproveModal(deposito);
    setApproveForm({
      interes: deposito.tipo === 'plazo_fijo' ? '5' : deposito.tipo === 'certificado' ? '3' : '',
      observaciones: '',
      pdfFile: null,
      uploadingPdf: false,
      pdfUrl: deposito.documento_url || ''
    });
  }

  async function uploadPdf() {
    if (!approveForm.pdfFile) {
      setError('Selecciona un archivo PDF primero');
      return;
    }

    setApproveForm(prev => ({ ...prev, uploadingPdf: true }));
    
    try {
      const formData = new FormData();
      formData.append('file', approveForm.pdfFile);
      formData.append('folder', 'documentos_depositos');
      
      const response = await fetch(`${import.meta.env.VITE_API_URL || 'http://localhost:8080'}/api/upload`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${user.token}`
        },
        body: formData
      });

      if (!response.ok) throw new Error('Error al subir el archivo');
      
      const data = await response.json();
      setApproveForm(prev => ({ ...prev, pdfUrl: data.url, uploadingPdf: false }));
      setSuccess('PDF subido correctamente');
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      setError(err.message || 'Error al subir PDF');
      setApproveForm(prev => ({ ...prev, uploadingPdf: false }));
    }
  }

  async function approveWithModal(approve = true) {
    if (!showApproveModal) return;

    const requiresPdf = showApproveModal.tipo === 'plazo_fijo' || showApproveModal.tipo === 'certificado';
    
    if (approve && requiresPdf && !approveForm.pdfUrl) {
      setError('Debes subir el documento PDF antes de aprobar');
      return;
    }

    if (approve && requiresPdf && !approveForm.interes) {
      setError('Debes ingresar el interés %');
      return;
    }

    setApproving(showApproveModal.id);
    const result = await approveDeposit(
      showApproveModal.id, 
      approve, 
      approveForm.observaciones,
      approve && requiresPdf ? approveForm.interes : null,
      approve && requiresPdf ? approveForm.pdfUrl : null
    );
    setApproving(null);

    if (result.success) {
      setSuccess(`Depósito ${approve ? 'aprobado' : 'rechazado'} correctamente`);
      setTimeout(() => setSuccess(null), 3000);
      setShowApproveModal(null);
      load();
    } else {
      setError(result.error);
    }
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
                <th>Voucher</th>
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
                  <td>
                    {d.archivo_url ? (
                      <button
                        onClick={() => setShowVoucherModal(d)}
                        style={{
                          color: '#0369a1',
                          background: 'transparent',
                          border: 'none',
                          textDecoration: 'underline',
                          cursor: 'pointer',
                          fontSize: '0.85rem',
                          fontWeight: '600'
                        }}
                      >
                        {d.voucher_is_pdf || d.archivo_url.toLowerCase().includes('.pdf') ? '📄 Ver PDF' : '🖼️ Ver Imagen'}
                      </button>
                    ) : (
                      <span style={{ color: '#999', fontSize: '0.85rem' }}>Sin archivo</span>
                    )}
                  </td>
                  <td>{getEstadoBadge(d.estado || (d.validado ? 'aprobado' : 'pendiente'))}</td>
                  <td>
                    <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                      {d.estado !== 'aprobado' && d.estado !== 'eliminado' && (
                        <>
                          {(d.tipo === 'plazo_fijo' || d.tipo === 'certificado') ? (
                            <button 
                              onClick={() => openApproveModal(d)}
                              disabled={approving === d.id}
                              style={{ 
                                background: approving === d.id ? '#ccc' : 'var(--success-color)',
                                color: '#fff',
                                padding: '6px 12px',
                                fontSize: '0.85rem'
                              }}
                            >
                              {approving === d.id ? '⏳' : '✓ Revisar'}
                            </button>
                          ) : (
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


      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '12px' }}>
        <button onClick={downloadReporteUsuarios} disabled={downloadingReport} style={{ background: downloadingReport ? '#ccc' : '#0ea5e9', color: '#fff', padding: '8px 12px', borderRadius: '6px', border: 'none', cursor: downloadingReport ? 'not-allowed' : 'pointer' }}>
          {downloadingReport ? 'Generando...' : '📄 Exportar Reporte PDF'}
        </button>
      </div>

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

      {/* Modal de Aprobación de Depósito (Plazo Fijo / Certificado) */}
      {showApproveModal && (
        <div className="modal-overlay" onClick={() => setShowApproveModal(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '600px', maxHeight: '90vh', overflowY: 'auto' }}>
            <h3>Aprobar {showApproveModal.tipo === 'plazo_fijo' ? 'Plazo Fijo' : 'Certificado'}</h3>

            <div style={{ background: '#f5f5f5', padding: '12px', borderRadius: '8px', marginBottom: '16px' }}>
              <p><strong>Usuario:</strong> {showApproveModal.id_usuario}</p>
              <p><strong>Monto:</strong> {formatCurrency(showApproveModal.monto)}</p>
              <p><strong>Tipo:</strong> {showApproveModal.tipo}</p>
              <p><strong>Fecha:</strong> {formatDate(showApproveModal.fecha_deposito)}</p>
            </div>

            {/* Interés % */}
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: '600' }}>
                📊 Interés Anual (%) *
              </label>
              <input
                type="number"
                step="0.1"
                value={approveForm.interes}
                onChange={(e) => setApproveForm(prev => ({ ...prev, interes: e.target.value }))}
                style={{ width: '100%', padding: '10px', fontSize: '16px', borderRadius: '6px', border: '2px solid #e0e0e0' }}
                placeholder="Ej: 5.0"
              />
              <small style={{ color: '#666', fontSize: '0.85rem' }}>
                Interés que se aplicará al {showApproveModal.tipo === 'plazo_fijo' ? 'plazo fijo' : 'certificado'}
              </small>
            </div>

            {/* Upload PDF */}
            <div style={{ marginBottom: '16px', padding: '16px', background: '#fff3cd', borderRadius: '8px', border: '2px solid #ffc107' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: '600', color: '#856404' }}>
                📄 Documento del {showApproveModal.tipo === 'plazo_fijo' ? 'Plazo Fijo' : 'Certificado'} (PDF) *Obligatorio
              </label>
              <input
                type="file"
                accept=".pdf"
                onChange={(e) => setApproveForm(prev => ({ ...prev, pdfFile: e.target.files[0] }))}
                style={{ marginBottom: '8px', display: 'block', width: '100%' }}
                disabled={approveForm.uploadingPdf}
              />
              <button
                onClick={uploadPdf}
                disabled={!approveForm.pdfFile || approveForm.uploadingPdf}
                style={{
                  background: approveForm.uploadingPdf ? '#ccc' : '#007bff',
                  color: '#fff',
                  padding: '8px 16px',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: approveForm.uploadingPdf || !approveForm.pdfFile ? 'not-allowed' : 'pointer',
                  fontSize: '0.9rem',
                  marginTop: '8px'
                }}
              >
                {approveForm.uploadingPdf ? '⏳ Subiendo...' : '⬆️ Subir PDF'}
              </button>
              {approveForm.pdfUrl && (
                <div style={{ marginTop: '8px', color: '#28a745', fontWeight: '600' }}>
                  ✅ PDF subido correctamente
                  <a href={approveForm.pdfUrl} target="_blank" rel="noopener noreferrer" style={{ marginLeft: '8px', color: '#007bff' }}>
                    Ver
                  </a>
                </div>
              )}
            </div>

            {/* Observaciones */}
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: '600' }}>
                📝 Observaciones (opcional)
              </label>
              <textarea
                value={approveForm.observaciones}
                onChange={(e) => setApproveForm(prev => ({ ...prev, observaciones: e.target.value }))}
                style={{ width: '100%', padding: '10px', fontSize: '14px', borderRadius: '6px', border: '2px solid #e0e0e0', minHeight: '80px' }}
                placeholder="Comentarios adicionales..."
              />
            </div>

            {/* Botones */}
            <div style={{ display: 'flex', gap: '12px', marginTop: '20px' }}>
              <button
                onClick={() => approveWithModal(true)}
                disabled={approving || !approveForm.pdfUrl || !approveForm.interes}
                style={{
                  flex: 1,
                  background: approving || !approveForm.pdfUrl || !approveForm.interes ? '#ccc' : '#28a745',
                  color: '#fff',
                  padding: '12px',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: approving || !approveForm.pdfUrl || !approveForm.interes ? 'not-allowed' : 'pointer',
                  fontSize: '1rem',
                  fontWeight: '600'
                }}
              >
                {approving ? '⏳ Procesando...' : '✅ Aprobar'}
              </button>
              <button
                onClick={() => approveWithModal(false)}
                disabled={approving}
                style={{
                  flex: 1,
                  background: approving ? '#ccc' : '#dc3545',
                  color: '#fff',
                  padding: '12px',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: approving ? 'not-allowed' : 'pointer',
                  fontSize: '1rem',
                  fontWeight: '600'
                }}
              >
                {approving ? '⏳' : '❌ Rechazar'}
              </button>
              <button
                onClick={() => setShowApproveModal(null)}
                disabled={approving}
                style={{
                  background: '#6c757d',
                  color: '#fff',
                  padding: '12px 20px',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: approving ? 'not-allowed' : 'pointer',
                  fontSize: '1rem'
                }}
              >
                Cerrar
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal de Visualización de Voucher */}
      {showVoucherModal && (
        <div className="modal-overlay" onClick={() => setShowVoucherModal(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '900px', maxHeight: '90vh', overflowY: 'auto' }}>
            <h3>Voucher de Depósito</h3>
            
            <div style={{ background: '#f5f5f5', padding: '12px', borderRadius: '8px', marginBottom: '16px' }}>
              <p><strong>Usuario:</strong> {showVoucherModal.id_usuario}</p>
              <p><strong>Tipo:</strong> {showVoucherModal.tipo}</p>
              <p><strong>Monto:</strong> {formatCurrency(showVoucherModal.monto)}</p>
              <p><strong>Fecha:</strong> {formatDate(showVoucherModal.fecha_deposito)}</p>
            </div>

            <div style={{ marginBottom: '16px', textAlign: 'center' }}>
              {showVoucherModal.voucher_is_pdf || showVoucherModal.archivo_url?.toLowerCase().includes('.pdf') ? (
                <iframe
                  src={showVoucherModal.archivo_url}
                  style={{ width: '100%', height: '600px', border: '1px solid #e0e0e0', borderRadius: '8px' }}
                  title="Voucher PDF"
                />
              ) : (
                <img
                  src={showVoucherModal.archivo_url}
                  alt="Voucher"
                  style={{ maxWidth: '100%', height: 'auto', borderRadius: '8px', border: '1px solid #e0e0e0' }}
                />
              )}
            </div>

            <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
              <a
                href={showVoucherModal.archivo_url}
                target="_blank"
                rel="noopener noreferrer"
                style={{
                  background: '#007bff',
                  color: '#fff',
                  padding: '10px 20px',
                  borderRadius: '6px',
                  textDecoration: 'none',
                  fontSize: '1rem'
                }}
              >
                🔗 Abrir en Nueva Pestaña
              </a>
              <button
                onClick={() => setShowVoucherModal(null)}
                style={{
                  background: '#6c757d',
                  color: '#fff',
                  padding: '10px 20px',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  fontSize: '1rem'
                }}
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
