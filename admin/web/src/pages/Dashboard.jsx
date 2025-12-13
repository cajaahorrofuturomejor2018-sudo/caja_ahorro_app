
import React, { useState } from 'react';
import UsuariosTab from './UsuariosTab';
import DepositosTab from './DepositosTab';
import PrestamosTab from './PrestamosTab';
import CajaTab from './CajaTab';
import ReportesTab from './ReportesTab';
import ConfiguracionTab from './ConfiguracionTab';
import AuditoriaTab from './AuditoriaTab';
import ValidacionesTab from './ValidacionesTab';

const TABS = [
  { label: 'Usuarios', component: UsuariosTab },
  { label: 'Depósitos', component: DepositosTab },
  { label: 'Préstamos', component: PrestamosTab },
  { label: 'Caja', component: CajaTab },
  { label: 'Reportes', component: ReportesTab },
  { label: 'Configuración', component: ConfiguracionTab },
  { label: 'Auditoría', component: AuditoriaTab },
  { label: 'Validaciones', component: ValidacionesTab },
];

export default function Dashboard({ user, onLogout }) {
  const [tab, setTab] = useState(0);
  const TabComponent = TABS[tab].component;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
      <header className="header">
        <div>
          <h1 style={{ margin: '0 0 4px 0', fontSize: 24 }}>Panel de Administrador</h1>
          <p style={{ margin: 0, fontSize: 12, opacity: 0.8 }}>Gestión de Caja de Ahorros</p>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ marginBottom: 8, fontSize: 14 }}>
            Sesión: <strong>{user.email}</strong>
          </div>
          <button onClick={onLogout} className="btn btn-secondary" style={{ padding: '6px 12px' }}>
            Cerrar sesión
          </button>
        </div>
      </header>

      <nav className="nav-tabs" style={{ display: 'flex', overflowX: 'auto', borderBottom: '1px solid #ddd', background: '#f5f5f5', padding: '0 16px' }}>
        {TABS.map((t, i) => (
          <button
            key={t.label}
            onClick={() => setTab(i)}
            className={tab === i ? 'tab-active' : 'tab-inactive'}
            style={{
              padding: '12px 16px',
              border: 'none',
              background: tab === i ? '#1976d2' : 'transparent',
              color: tab === i ? '#fff' : '#666',
              cursor: 'pointer',
              fontSize: 14,
              fontWeight: tab === i ? 'bold' : 'normal',
              borderRadius: '4px 4px 0 0',
              whiteSpace: 'nowrap',
              transition: '0.2s'
            }}
          >
            {t.label}
          </button>
        ))}
      </nav>

      <main style={{ flex: 1, padding: 16, overflowY: 'auto' }}>
        <div className="card">
          <TabComponent user={user} />
        </div>
      </main>
    </div>
  );
}
