import React, { useEffect, useState } from 'react';
import { apiGet, apiPost, setAuthToken } from '../utils/apiClient.js';
import { formatDate, formatCurrency, getEstadoBadge } from '../utils/formatters.jsx';

export default function PrestamosTab({ user }) {
  const [prestamos, setPrestamos] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [approving, setApproving] = useState(null);
  const [showApproveModal, setShowApproveModal] = useState(null);
  const [approveForm, setApproveForm] = useState({
    interes: '',
    plazoMeses: '',
    montoAprobado: '',
    observaciones: '',
    pdfFile: null,
    uploadingPdf: false,
    pdfUrl: ''
  });
  const [showReviewModal, setShowReviewModal] = useState(null);
  const [pagoForm, setPagoForm] = useState({ monto: '', descripcion: '' });
  const [addingPago, setAddingPago] = useState(false);

  useEffect(() => {
    if (user?.token) {
      setAuthToken(user.token);
      load();
    }
  }, [user]);

  async function load() {
    setLoading(true);
    setError(null);
    const result = await apiGet('/prestamos');
    if (result.success) {
      setPrestamos(result.data || []);
    } else {
      setError(result.error);
    }
    setLoading(false);
  }

  function openApproveModal(prestamo) {
    setShowApproveModal(prestamo);
    setApproveForm({
      interes: prestamo.interes || '5',
      plazoMeses: prestamo.plazo_meses || '12',
      montoAprobado: prestamo.monto_solicitado || '',
      observaciones: '',
      pdfFile: null,
      uploadingPdf: false,
      pdfUrl: prestamo.documento_contrato_url || ''
    });
  }

  async function uploadPdf() {
    if (!approveForm.pdfFile) {
      setError('Selecciona un archivo PDF primero');
      return;
    }

    setApproveForm(prev => ({ ...prev, uploadingPdf: true }));
    
    try {
      // Subir a Firebase Storage
      const formData = new FormData();
      formData.append('file', approveForm.pdfFile);
      formData.append('folder', 'contratos_prestamos');
      
      const base = import.meta.env.VITE_API_URL || 'http://localhost:8080';
      // Si base es '/api', no duplicar el segmento 'api' en la ruta
      const uploadUrl = base.endsWith('/api') ? `${base}/upload` : `${base}/api/upload`;
      const response = await fetch(uploadUrl, {
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

  async function approve(approve = true) {
    if (!showApproveModal) return;

    if (approve && !approveForm.pdfUrl) {
      setError('Debes subir el contrato PDF antes de aprobar');
      return;
    }

    if (!window.confirm(`¿Estás seguro de ${approve ? 'aprobar' : 'rechazar'} este préstamo?`)) return;

    setApproving(showApproveModal.id);
    const result = await apiPost(`/prestamos/${showApproveModal.id}/approve`, { 
      approve,
      interes: parseFloat(approveForm.interes) || 0,
      plazoMeses: parseInt(approveForm.plazoMeses) || 12,
      montoAprobado: parseFloat(approveForm.montoAprobado) || parseFloat(showApproveModal.monto_solicitado),
      observaciones: approveForm.observaciones,
      documentoContratoUrl: approveForm.pdfUrl
    });
    setApproving(null);

    if (result.success) {
      setSuccess(`Préstamo ${approve ? 'aprobado' : 'rechazado'} correctamente`);
      setTimeout(() => setSuccess(null), 4000);
      setShowApproveModal(null);
      load();
    } else {
      setError(result.error);
    }
  }

  async function reject() {
    if (!showApproveModal) return;
    
    if (!window.confirm('¿Estás seguro de rechazar este préstamo?')) return;

    setApproving(showApproveModal.id);
    const result = await apiPost(`/prestamos/${showApproveModal.id}/approve`, { 
      approve: false,
      observaciones: approveForm.observaciones
    });
    setApproving(null);

    if (result.success) {
      setSuccess('Préstamo rechazado');
      setTimeout(() => setSuccess(null), 3000);
      setShowApproveModal(null);
      load();
    } else {
      setError(result.error);
    }
  }

  async function precancelar(id) {
    if (!window.confirm('¿Precancelar este préstamo? El estado pasará a FINALIZADO y no se cobrará más.')) return;

    setApproving(id);
    const result = await apiPost(`/prestamos/${id}/precancelar`, {});
    setApproving(null);

    if (result.success) {
      setSuccess('Préstamo precancelado. Estado: PRESTAMO FINALIZADO');
      setTimeout(() => setSuccess(null), 3000);
      load();
    } else {
      setError(result.error);
    }
  }

  async function addPago() {
    if (!showReviewModal || !pagoForm.monto) {
      setError('Ingrese el monto del pago');
      return;
    }

    setAddingPago(true);
    const result = await apiPost(`/prestamos/${showReviewModal.id}/pagos`, {
      monto: parseFloat(pagoForm.monto),
      descripcion: pagoForm.descripcion || 'Pago registrado por admin',
      fecha: new Date().toISOString()
    });
    setAddingPago(false);

    if (result.success) {
      setSuccess('Pago registrado correctamente');
      setTimeout(() => setSuccess(null), 3000);
      setPagoForm({ monto: '', descripcion: '' });
      setShowReviewModal(null);
      load();
    } else {
      setError(result.error);
    }
  }

  return (
    <div>
      <h2>💳 Préstamos</h2>

      {success && <div className="success">{success}</div>}
      {error && <div className="error">{error}</div>}

      {loading ? (
        <div className="info">⏳ Cargando préstamos...</div>
      ) : prestamos.length === 0 ? (
        <div className="warning">⚠️ No hay préstamos registrados</div>
      ) : (
        <div style={{ overflowX: 'auto' }}>
          <table>
            <thead>
              <tr>
                <th>Usuario</th>
                <th>Monto Solicitado</th>
                <th>Plazo</th>
                <th>Estado</th>
                <th>Documento</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              {prestamos.map(p => (
                <tr key={p.id}>
                  <td style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                    {p.id_usuario?.substring(0, 8) || '-'}
                  </td>
                  <td style={{ fontWeight: 'bold' }}>{formatCurrency(p.monto_solicitado)}</td>
                  <td>{p.plazo_meses || 12} meses</td>
                  <td>{getEstadoBadge(p.estado || p.estado_usuario || 'pendiente')}</td>
                  <td>
                    {p.documento_contrato_url ? (
                      <a 
                        href={p.documento_contrato_url} 
                        target="_blank" 
                        rel="noopener noreferrer"
                        style={{
                          color: 'var(--primary-color)',
                          textDecoration: 'none',
                          fontSize: '0.85rem',
                          fontWeight: '600'
                        }}
                      >
                        📄 Ver Contrato
                      </a>
                    ) : (
                      <span style={{ color: '#999', fontSize: '0.85rem' }}>Sin documento</span>
                    )}
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                      {/* Pendiente: Aprobar/Rechazar */}
                      {(p.estado === 'pendiente' || !p.estado || p.estado === null) && (
                        <>
                          <button
                            onClick={() => openApproveModal(p)}
                            disabled={approving === p.id}
                            style={{
                              background: approving === p.id ? '#ccc' : 'var(--success-color)',
                              color: '#fff',
                              padding: '6px 12px',
                              fontSize: '0.85rem',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: approving === p.id ? 'not-allowed' : 'pointer'
                            }}
                            title="Revisar y aprobar préstamo"
                          >
                            {approving === p.id ? '⏳' : '✓ Revisar'}
                          </button>
                        </>
                      )}

                      {/* Activo: Precancelar (pago anticipado) */}
                      {p.estado === 'activo' && (
                        <>
                          <div style={{ fontSize: '0.75rem', color: '#666', marginBottom: '4px', width: '100%' }}>
                            <strong>Cuota:</strong> {formatCurrency(p.cuota_mensual)} | 
                            <strong> Próx. Pago:</strong> {formatDate(p.proxima_fecha_pago)}
                          </div>
                          <button
                            onClick={() => setShowReviewModal(p)}
                            style={{
                              background: '#3b82f6',
                              color: '#fff',
                              padding: '6px 12px',
                              fontSize: '0.85rem',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer'
                            }}
                            title="Ver detalles, contrato y registrar pagos"
                          >
                            📋 Revisar
                          </button>
                          <button
                            onClick={() => precancelar(p.id)}
                            disabled={approving === p.id}
                            style={{
                              background: approving === p.id ? '#ccc' : '#f59e0b',
                              color: '#fff',
                              padding: '6px 12px',
                              fontSize: '0.85rem',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: approving === p.id ? 'not-allowed' : 'pointer'
                            }}
                            title="Usuario pagó en un solo pago → PRESTAMO FINALIZADO"
                          >
                            {approving === p.id ? '⏳' : '⚡ Precancelar'}
                          </button>
                        </>
                      )}

                      {/* Finalizado: Sin acciones */}
                      {p.estado === 'finalizado' && (
                        <span style={{
                          background: '#10b981',
                          color: '#fff',
                          padding: '6px 12px',
                          borderRadius: '6px',
                          fontSize: '0.85rem',
                          fontWeight: 'bold'
                        }}>
                          ✓ Finalizado
                        </span>
                      )}

                      {/* Rechazado: Sin acciones */}
                      {p.estado === 'rechazado' && (
                        <span style={{
                          background: '#ef4444',
                          color: '#fff',
                          padding: '6px 12px',
                          borderRadius: '6px',
                          fontSize: '0.85rem',
                          fontWeight: 'bold'
                        }}>
                          ✗ Rechazado
                        </span>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Modal de Aprobación */}
      {showApproveModal && (
        <div className="modal-overlay" onClick={() => setShowApproveModal(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '600px', maxHeight: '90vh', overflowY: 'auto' }}>
            <h3>Aprobar Préstamo</h3>

            <div style={{ background: '#f5f5f5', padding: '12px', borderRadius: '8px', marginBottom: '16px' }}>
              <p><strong>Usuario:</strong> {showApproveModal.id_usuario}</p>
              <p><strong>Monto Solicitado:</strong> {formatCurrency(showApproveModal.monto_solicitado)}</p>
              <p><strong>Plazo Solicitado:</strong> {showApproveModal.plazo_meses || 12} meses</p>
            </div>

            {/* Monto Aprobado */}
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: '600' }}>
                💰 Monto a Aprobar (S/)
              </label>
              <input
                type="number"
                step="0.01"
                value={approveForm.montoAprobado}
                onChange={(e) => setApproveForm(prev => ({ ...prev, montoAprobado: e.target.value }))}
                style={{ width: '100%', padding: '10px', fontSize: '16px', borderRadius: '6px', border: '2px solid #e0e0e0' }}
                placeholder="Monto a aprobar"
              />
            </div>

            {/* Interés % */}
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: '600' }}>
                📊 Interés Anual (%)
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
                Interés que se cobrará sobre el monto del préstamo
              </small>
            </div>

            {/* Plazo */}
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: '600' }}>
                📅 Plazo (meses)
              </label>
              <input
                type="number"
                value={approveForm.plazoMeses}
                onChange={(e) => setApproveForm(prev => ({ ...prev, plazoMeses: e.target.value }))}
                style={{ width: '100%', padding: '10px', fontSize: '16px', borderRadius: '6px', border: '2px solid #e0e0e0' }}
                placeholder="12"
              />
            </div>

            {/* Upload PDF */}
            <div style={{ marginBottom: '16px', padding: '16px', background: '#fff3cd', borderRadius: '8px', border: '2px solid #ffc107' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: '600', color: '#856404' }}>
                📄 Contrato de Préstamo (PDF) *Obligatorio
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
                placeholder="Comentarios o condiciones adicionales..."
              />
            </div>

            {/* Botones */}
            <div style={{ display: 'flex', gap: '12px', marginTop: '20px' }}>
              <button
                onClick={() => approve(true)}
                disabled={approving || !approveForm.pdfUrl}
                style={{
                  flex: 1,
                  background: approving || !approveForm.pdfUrl ? '#ccc' : '#28a745',
                  color: '#fff',
                  padding: '12px',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: approving || !approveForm.pdfUrl ? 'not-allowed' : 'pointer',
                  fontSize: '1rem',
                  fontWeight: '600'
                }}
              >
                {approving ? '⏳ Procesando...' : '✅ Aprobar Préstamo'}
              </button>
              <button
                onClick={reject}
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

      {/* Modal de Revisión de Préstamo Activo */}
      {showReviewModal && (
        <div className="modal-overlay" onClick={() => setShowReviewModal(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} style={{ maxWidth: '700px', maxHeight: '90vh', overflowY: 'auto' }}>
            <h3>📋 Detalles del Préstamo</h3>

            <div style={{ background: '#f5f5f5', padding: '16px', borderRadius: '8px', marginBottom: '16px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div>
                  <strong>Usuario:</strong><br/>
                  <span style={{ fontSize: '0.85rem', color: '#666' }}>{showReviewModal.id_usuario}</span>
                </div>
                <div>
                  <strong>Estado:</strong><br/>
                  {getEstadoBadge(showReviewModal.estado)}
                </div>
                <div>
                  <strong>Monto Aprobado:</strong><br/>
                  <span style={{ fontSize: '1.1rem', fontWeight: 'bold', color: '#10b981' }}>
                    {formatCurrency(showReviewModal.monto_aprobado)}
                  </span>
                </div>
                <div>
                  <strong>Saldo Pendiente:</strong><br/>
                  <span style={{ fontSize: '1.1rem', fontWeight: 'bold', color: '#ef4444' }}>
                    {formatCurrency(showReviewModal.saldo_pendiente)}
                  </span>
                </div>
                <div>
                  <strong>Cuota Mensual:</strong><br/>
                  {formatCurrency(showReviewModal.cuota_mensual)}
                </div>
                <div>
                  <strong>Interés:</strong><br/>
                  {showReviewModal.interes}%
                </div>
                <div>
                  <strong>Plazo:</strong><br/>
                  {showReviewModal.plazo_meses} meses
                </div>
                <div>
                  <strong>Meses Restantes:</strong><br/>
                  {showReviewModal.meses_restantes} meses
                </div>
                <div>
                  <strong>Próximo Pago:</strong><br/>
                  {formatDate(showReviewModal.proxima_fecha_pago)}
                </div>
                <div>
                  <strong>Fecha Aprobación:</strong><br/>
                  {formatDate(showReviewModal.fecha_aprobacion)}
                </div>
              </div>
            </div>

            {/* Contrato */}
            {showReviewModal.documento_contrato_url && (
              <div style={{ marginBottom: '16px', padding: '12px', background: '#e0f2fe', borderRadius: '8px' }}>
                <strong>📄 Contrato:</strong>
                <a
                  href={showReviewModal.documento_contrato_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{ marginLeft: '8px', color: '#0369a1', fontWeight: '600' }}
                >
                  Ver PDF
                </a>
              </div>
            )}

            {/* Historial de Pagos */}
            {showReviewModal.historial_pagos && showReviewModal.historial_pagos.length > 0 && (
              <div style={{ marginBottom: '16px' }}>
                <h4>Historial de Pagos</h4>
                <div style={{ maxHeight: '200px', overflowY: 'auto', border: '1px solid #e0e0e0', borderRadius: '8px' }}>
                  <table style={{ width: '100%', fontSize: '0.85rem' }}>
                    <thead>
                      <tr style={{ background: '#f5f5f5' }}>
                        <th style={{ padding: '8px', textAlign: 'left' }}>Fecha</th>
                        <th style={{ padding: '8px', textAlign: 'right' }}>Monto</th>
                        <th style={{ padding: '8px', textAlign: 'left' }}>Descripción</th>
                      </tr>
                    </thead>
                    <tbody>
                      {showReviewModal.historial_pagos.map((pago, idx) => (
                        <tr key={idx} style={{ borderBottom: '1px solid #f0f0f0' }}>
                          <td style={{ padding: '8px' }}>{formatDate(pago.fecha)}</td>
                          <td style={{ padding: '8px', textAlign: 'right', fontWeight: 'bold', color: '#10b981' }}>
                            {formatCurrency(pago.monto)}
                          </td>
                          <td style={{ padding: '8px', fontSize: '0.8rem', color: '#666' }}>
                            {pago.descripcion || '-'}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            {/* Registrar Nuevo Pago */}
            <div style={{ marginTop: '20px', padding: '16px', background: '#fff3cd', borderRadius: '8px', border: '2px solid #ffc107' }}>
              <h4 style={{ marginTop: 0, color: '#856404' }}>💰 Registrar Pago</h4>
              <div style={{ marginBottom: '12px' }}>
                <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600' }}>Monto (S/)</label>
                <input
                  type="number"
                  step="0.01"
                  value={pagoForm.monto}
                  onChange={(e) => setPagoForm(prev => ({ ...prev, monto: e.target.value }))}
                  style={{ width: '100%', padding: '8px', fontSize: '16px', borderRadius: '6px', border: '2px solid #e0e0e0' }}
                  placeholder="Ej: 150.00"
                />
              </div>
              <div style={{ marginBottom: '12px' }}>
                <label style={{ display: 'block', marginBottom: '4px', fontWeight: '600' }}>Descripción (opcional)</label>
                <input
                  type="text"
                  value={pagoForm.descripcion}
                  onChange={(e) => setPagoForm(prev => ({ ...prev, descripcion: e.target.value }))}
                  style={{ width: '100%', padding: '8px', fontSize: '14px', borderRadius: '6px', border: '2px solid #e0e0e0' }}
                  placeholder="Ej: Cuota mes de diciembre"
                />
              </div>
              <button
                onClick={addPago}
                disabled={addingPago || !pagoForm.monto}
                style={{
                  background: addingPago || !pagoForm.monto ? '#ccc' : '#28a745',
                  color: '#fff',
                  padding: '10px 20px',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: addingPago || !pagoForm.monto ? 'not-allowed' : 'pointer',
                  fontSize: '1rem',
                  fontWeight: '600',
                  width: '100%'
                }}
              >
                {addingPago ? '⏳ Registrando...' : '✅ Registrar Pago'}
              </button>
            </div>

            <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'flex-end' }}>
              <button
                onClick={() => setShowReviewModal(null)}
                style={{
                  background: '#6c757d',
                  color: '#fff',
                  padding: '10px 24px',
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
