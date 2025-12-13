import React, { useEffect, useState } from 'react';
import { fetchCaja, setAuthToken } from '../utils/apiClient.js';
import { formatCurrency, formatDate } from '../utils/formatters.jsx';

export default function CajaTab({ user }) {
  const [caja, setCaja] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [movimientos, setMovimientos] = useState([]);

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
      setCaja(result.data || {});
      setMovimientos([
        { tipo: 'Depósitos', monto: result.data?.total_depositos || 0, icono: '📥', color: '#10b981' },
        { tipo: 'Préstamos Desembolsados', monto: result.data?.total_prestamos || 0, icono: '💳', color: '#ef4444' },
        { tipo: 'Pagos Recibidos', monto: 0, icono: '✅', color: '#10b981' },
      ]);
    } else {
      setError(result.error);
    }
    setLoading(false);
  }

  const saldoActual = caja?.saldo ?? 0;
  const totalIngresos = (caja?.total_depositos || 0) + (caja?.total_pagos_recibidos || 0);
  const totalEgresos = caja?.total_prestamos || 0;

  return (
    <div style={{ padding: '20px' }}>
      <h2 style={{ marginBottom: '20px' }}>💰 Estado de Caja</h2>

      {error && <div style={{ background: '#fee2e2', color: '#991b1b', padding: '12px', borderRadius: '8px', marginBottom: '16px' }}>{error}</div>}

      {loading ? (
        <div style={{ textAlign: 'center', color: '#666' }}>Cargando...</div>
      ) : (
        <>
          <div style={{ background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)', color: '#fff', padding: '24px', borderRadius: '12px', marginBottom: '20px', boxShadow: '0 4px 6px rgba(0,0,0,0.1)' }}>
            <h3 style={{ margin: '0 0 12px 0', opacity: 0.9 }}>Saldo Actual de Caja</h3>
            <div style={{ fontSize: '36px', fontWeight: 'bold' }}>${saldoActual.toFixed(2)}</div>
            <p style={{ margin: '8px 0 0 0', opacity: 0.8, fontSize: '12px' }}>Última actualización: {formatDate(new Date())}</p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px', marginBottom: '24px' }}>
            <div style={{ background: '#ecfdf5', padding: '16px', borderRadius: '8px', borderLeft: '4px solid #10b981' }}>
              <p style={{ margin: '0 0 8px 0', color: '#666', fontSize: '12px', fontWeight: '600' }}>Total Ingresos</p>
              <p style={{ margin: 0, fontSize: '20px', fontWeight: 'bold', color: '#10b981' }}>${totalIngresos.toFixed(2)}</p>
            </div>
            <div style={{ background: '#fef2f2', padding: '16px', borderRadius: '8px', borderLeft: '4px solid #ef4444' }}>
              <p style={{ margin: '0 0 8px 0', color: '#666', fontSize: '12px', fontWeight: '600' }}>Total Egresos</p>
              <p style={{ margin: 0, fontSize: '20px', fontWeight: 'bold', color: '#ef4444' }}>${totalEgresos.toFixed(2)}</p>
            </div>
            <div style={{ background: '#fefce8', padding: '16px', borderRadius: '8px', borderLeft: '4px solid #eab308' }}>
              <p style={{ margin: '0 0 8px 0', color: '#666', fontSize: '12px', fontWeight: '600' }}>Capital Neto</p>
              <p style={{ margin: 0, fontSize: '20px', fontWeight: 'bold', color: '#eab308' }}>${(totalIngresos - totalEgresos).toFixed(2)}</p>
            </div>
          </div>

          <div style={{ background: '#fef08a', border: '1px solid #fcd34d', padding: '12px', borderRadius: '8px', marginBottom: '20px', color: '#92400e', fontSize: '13px' }}>
            ⚠️ <strong>Nota:</strong> El saldo de caja se actualiza automáticamente según las transacciones. No se puede editar manualmente.
          </div>

          <div style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: '8px', overflow: 'hidden' }}>
            <h3 style={{ margin: 0, padding: '16px', background: '#f9fafb', borderBottom: '1px solid #e5e7eb' }}>Resumen de Transacciones</h3>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead style={{ background: '#f3f4f6' }}>
                <tr>
                  <th style={{ padding: '12px', textAlign: 'left', fontWeight: '600', fontSize: '13px', color: '#6b7280', borderBottom: '1px solid #e5e7eb' }}>Tipo</th>
                  <th style={{ padding: '12px', textAlign: 'right', fontWeight: '600', fontSize: '13px', color: '#6b7280', borderBottom: '1px solid #e5e7eb' }}>Monto</th>
                </tr>
              </thead>
              <tbody>
                {movimientos.map((m, i) => (
                  <tr key={i} style={{ borderBottom: '1px solid #e5e7eb' }}>
                    <td style={{ padding: '12px', fontSize: '14px', color: '#1f2937' }}>{m.icono} {m.tipo}</td>
                    <td style={{ padding: '12px', textAlign: 'right', fontSize: '14px', fontWeight: '500', color: m.color }}>${m.monto.toFixed(2)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  );
}
