import React, { useEffect, useState } from 'react';
import { fetchAggregateTotals, setAuthToken } from '../utils/apiClient.js';

export default function ReportesTab({ user }) {
  const [totals, setTotals] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [downloadingPdf, setDownloadingPdf] = useState(false);

  async function loadTotals() {
    setLoading(true);
    setError(null);
    const result = await fetchAggregateTotals();
    if (result.success) {
      setTotals(result.data);
    } else {
      setError(result.error);
    }
    setLoading(false);
  }

  useEffect(() => {
    if (user?.token) {
      setAuthToken(user.token);
      loadTotals();
    }
  }, [user]);

  function downloadJSON() {
    const content = JSON.stringify({ 
      generated_at: new Date().toISOString(), 
      totals 
    }, null, 2);
    const blob = new Blob([content], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `reporte_aggregate_${new Date().toISOString().split('T')[0]}.json`;
    a.click();
    URL.revokeObjectURL(url);
  }

  function downloadCSV() {
    const rows = [
      ['Concepto', 'Monto (S/)'],
      ['Total Depósitos', totals?.total_depositos || 0],
      ['Total Préstamos', totals?.total_prestamos || 0],
      ['Total Aportes Extras', totals?.total_aportes_extras || 0],
      ['Total Retirados', totals?.total_retirado || 0],
    ];

    const csv = rows.map(row => row.map(cell => `"${cell}"`).join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `reporte_${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  async function downloadPDF() {
    try {
      setDownloadingPdf(true);
      const base = import.meta.env.VITE_API_URL || 'http://localhost:8080';
      const resp = await fetch(`${base}/api/reportes/usuarios`, {
        headers: { Authorization: `Bearer ${user.token}` }
      });
      if (!resp.ok) throw new Error('Error generando PDF');
      const blob = await resp.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `reporte_usuarios_${new Date().toISOString().split('T')[0]}.pdf`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);
    } catch (e) {
      setError(e.message || 'Error al descargar PDF');
    } finally {
      setDownloadingPdf(false);
    }
  }

  return (
    <div>
      <h2>Reportes de Agregados</h2>

      {error && <div className="alert alert-error">{error}</div>}

      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
        <button onClick={loadTotals} disabled={loading}>
          {loading ? 'Actualizando...' : 'Actualizar Datos'}
        </button>
        <button onClick={downloadJSON} disabled={!totals || loading}>Descargar JSON</button>
        <button onClick={downloadCSV} disabled={!totals || loading}>Descargar CSV</button>
        <button 
          onClick={downloadPDF} 
          disabled={!totals || loading || downloadingPdf}
          style={{ 
            background: downloadingPdf ? '#ccc' : '#10b981', 
            color: '#fff', 
            padding: '8px 16px', 
            borderRadius: '6px', 
            border: 'none', 
            cursor: downloadingPdf ? 'not-allowed' : 'pointer',
            fontWeight: 'bold'
          }}
        >
          {downloadingPdf ? '⏳ Generando PDF...' : '📄 Exportar Reporte PDF'}
        </button>
      </div>

      {loading ? (
        <div className="alert alert-info">Cargando datos...</div>
      ) : totals ? (
        <div className="grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 16 }}>
          <div className="card" style={{ padding: 16, background: '#e3f2fd' }}>
            <h4 style={{ margin: '0 0 8px 0', color: '#1976d2' }}>Total Depósitos</h4>
            <p style={{ margin: 0, fontSize: 24, fontWeight: 'bold', color: '#1976d2' }}>
              S/ {totals.total_depositos?.toFixed(2) || '0.00'}
            </p>
          </div>

          <div className="card" style={{ padding: 16, background: '#f3e5f5' }}>
            <h4 style={{ margin: '0 0 8px 0', color: '#7b1fa2' }}>Total Préstamos</h4>
            <p style={{ margin: 0, fontSize: 24, fontWeight: 'bold', color: '#7b1fa2' }}>
              S/ {totals.total_prestamos?.toFixed(2) || '0.00'}
            </p>
          </div>

          <div className="card" style={{ padding: 16, background: '#e8f5e9' }}>
            <h4 style={{ margin: '0 0 8px 0', color: '#388e3c' }}>Aportes Extras</h4>
            <p style={{ margin: 0, fontSize: 24, fontWeight: 'bold', color: '#388e3c' }}>
              S/ {totals.total_aportes_extras?.toFixed(2) || '0.00'}
            </p>
          </div>

          <div className="card" style={{ padding: 16, background: '#fce4ec' }}>
            <h4 style={{ margin: '0 0 8px 0', color: '#c2185b' }}>Total Retirado</h4>
            <p style={{ margin: 0, fontSize: 24, fontWeight: 'bold', color: '#c2185b' }}>
              S/ {totals.total_retirado?.toFixed(2) || '0.00'}
            </p>
          </div>
        </div>
      ) : (
        <div className="alert alert-warning">No hay datos disponibles</div>
      )}

      {totals && (
        <div className="card" style={{ marginTop: 16, padding: 16 }}>
          <h3>Detalles Completos</h3>
          <pre style={{ background: '#f5f5f5', padding: 12, borderRadius: 4, overflow: 'auto', maxHeight: 300 }}>
            {JSON.stringify(totals, null, 2)}
          </pre>
        </div>
      )}
    </div>
  );
}
