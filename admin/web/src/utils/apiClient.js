import axios from 'axios';

const getBaseURL = () => {
  const envUrl = import.meta.env.VITE_API_URL;
  if (envUrl) return envUrl;
  
  // Default fallback
  if (typeof window !== 'undefined' && window.location.hostname === 'localhost') {
    return 'http://localhost:8080';
  }
  return '';
};

const client = axios.create({
  baseURL: getBaseURL(),
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

/**
 * Set Bearer token for authenticated requests
 */
export function setAuthToken(token) {
  if (token) {
    client.defaults.headers.common['Authorization'] = `Bearer ${token}`;
  } else {
    delete client.defaults.headers.common['Authorization'];
  }
}

/**
 * Generic GET request with error handling
 */
export async function apiGet(endpoint, config = {}) {
  try {
    const response = await client.get(endpoint, config);
    return { success: true, data: response.data };
  } catch (error) {
    return { success: false, error: error.response?.data?.error || error.message || 'Error desconocido' };
  }
}

/**
 * Generic POST request with error handling
 */
export async function apiPost(endpoint, payload = {}, config = {}) {
  try {
    const response = await client.post(endpoint, payload, config);
    return { success: true, data: response.data };
  } catch (error) {
    return { success: false, error: error.response?.data?.error || error.message || 'Error desconocido' };
  }
}

/**
 * Generic PUT request with error handling
 */
export async function apiPut(endpoint, payload = {}, config = {}) {
  try {
    const response = await client.put(endpoint, payload, config);
    return { success: true, data: response.data };
  } catch (error) {
    return { success: false, error: error.response?.data?.error || error.message || 'Error desconocido' };
  }
}

/**
 * Generic DELETE request with error handling
 */
export async function apiDelete(endpoint, config = {}) {
  try {
    const response = await client.delete(endpoint, config);
    return { success: true, data: response.data };
  } catch (error) {
    return { success: false, error: error.response?.data?.error || error.message || 'Error desconocido' };
  }
}

// ============================================
// Specific API methods for Admin Dashboard
// ============================================

/**
 * Fetch all deposits
 */
export async function fetchDeposits() {
  return apiGet('/deposits');
}

/**
 * Fetch pending deposits for validation
 */
export async function fetchPendingDeposits() {
  return apiGet('/deposits/pending');
}

/**
 * Approve or reject a deposit
 */
export async function approveDeposit(depositId, approve = true, observaciones = '') {
  return apiPost(`/deposits/${depositId}/approve`, { approve, observaciones });
}

/**
 * Fetch all users
 */
export async function fetchUsers() {
  return apiGet('/users');
}

/**
 * Create a new user
 */
export async function createUser(userData) {
  return apiPost('/users', userData);
}

/**
 * Update user role
 */
export async function updateUserRole(userId, role) {
  return apiPost(`/users/${userId}/role`, { role });
}

/**
 * Update user estado (state)
 */
export async function updateUserEstado(userId, estado) {
  return apiPost(`/users/${userId}/estado`, { estado });
}

/**
 * Fetch caja balance
 */
export async function fetchCaja() {
  return apiGet('/caja');
}

/**
 * Update caja balance
 */
export async function updateCaja(saldo) {
  return apiPost('/caja', { saldo });
}

/**
 * Fetch configuration
 */
export async function fetchConfig() {
  return apiGet('/config');
}

/**
 * Update configuration
 */
export async function updateConfig(configData) {
  return apiPost('/config', configData);
}

/**
 * Fetch movimientos (audit log)
 */
export async function fetchMovimientos() {
  return apiGet('/movimientos');
}

/**
 * Delete (soft-delete) a deposit
 */
export async function deleteDeposit(depositId, motivo = '') {
  return apiDelete(`/deposits/${depositId}`, { data: { motivo } });
}

/**
 * Add an aporte (deposit as admin)
 */
export async function addAporte(aporteData) {
  return apiPost('/aportes', aporteData);
}

/**
 * Fetch aggregated totals
 */
export async function fetchAggregateTotals() {
  return apiGet('/aggregate_totals');
}

export default client;
