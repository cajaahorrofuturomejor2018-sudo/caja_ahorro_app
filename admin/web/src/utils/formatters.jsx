/**
 * Format Firestore timestamp or ISO string to readable date
 */
export function formatDate(timestamp) {
  if (!timestamp) return '-';
  
  try {
    let date;
    
    // Handle Firestore Timestamp object
    if (timestamp && typeof timestamp === 'object') {
      if (timestamp.toDate && typeof timestamp.toDate === 'function') {
        date = timestamp.toDate();
      } else if (timestamp._seconds !== undefined) {
        date = new Date(timestamp._seconds * 1000);
      } else if (timestamp.seconds !== undefined) {
        date = new Date(timestamp.seconds * 1000);
      }
    }
    
    // Handle ISO string or Date
    if (!date) {
      date = new Date(timestamp);
    }
    
    // Validate date
    if (isNaN(date.getTime())) return '-';
    
    return date.toLocaleDateString('es-PE', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    });
  } catch (e) {
    console.warn('Error formatting date:', e);
    return '-';
  }
}

/**
 * Format currency
 */
export function formatCurrency(amount) {
  if (amount === null || amount === undefined) return 'S/ 0.00';
  const num = parseFloat(amount);
  if (isNaN(num)) return 'S/ 0.00';
  return `S/ ${num.toFixed(2)}`;
}

/**
 * Format estado badge
 */
export function getEstadoBadge(estado) {
  const badges = {
    aprobado: { bg: '#4caf50', text: 'Aprobado' },
    rechazado: { bg: '#f44336', text: 'Rechazado' },
    pendiente: { bg: '#ff9800', text: 'Pendiente' },
    eliminado: { bg: '#9e9e9e', text: 'Eliminado' },
    activo: { bg: '#2196f3', text: 'Activo' },
    inactivo: { bg: '#757575', text: 'Inactivo' },
    cancelado: { bg: '#e91e63', text: 'Cancelado' }
  };
  
  const defaultBadge = { bg: '#9e9e9e', text: estado || '-' };
  const badge = badges[estado?.toLowerCase()] || defaultBadge;
  
  return (
    <span style={{
      background: badge.bg,
      color: '#fff',
      padding: '4px 12px',
      borderRadius: '12px',
      fontSize: '12px',
      fontWeight: 'bold',
      display: 'inline-block'
    }}>
      {badge.text}
    </span>
  );
}
