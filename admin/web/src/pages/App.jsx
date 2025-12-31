import React, { useEffect, useState } from 'react';
import Login from './Login';
import Dashboard from './Dashboard';
import { setAuthToken } from '../utils/apiClient.js';

export default function App() {
  const [user, setUser] = useState(null);

  // Al montar, restaurar sesión desde localStorage y aplicar token
  useEffect(() => {
    try {
      const saved = localStorage.getItem('adminUser');
      if (saved) {
        const u = JSON.parse(saved);
        if (u?.token) {
          setUser(u);
          setAuthToken(u.token);
        }
      }
    } catch (_) {}
  }, []);

  // Cada vez que cambia user, persistir y aplicar token
  useEffect(() => {
    if (user?.token) {
      try {
        localStorage.setItem('adminUser', JSON.stringify(user));
      } catch (_) {}
      setAuthToken(user.token);
    }
  }, [user]);

  return (
    <div>
      {!user ? (
        <Login onLogin={setUser} />
      ) : (
        <Dashboard
          user={user}
          onLogout={() => {
            try { localStorage.removeItem('adminUser'); } catch (_) {}
            setAuthToken(null);
            setUser(null);
          }}
        />
      )}
    </div>
  );
}
