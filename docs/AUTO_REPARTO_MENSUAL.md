# 🚀 Auto-Reparto Mensual de Depósitos

## 📋 Descripción

El sistema ahora **reparte automáticamente** los depósitos de ahorro mensual en cuotas de $25 por mes. Esto evita que usuarios que pagan múltiples meses a la vez sean penalizados incorrectamente.

## 💰 Funcionamiento

### Regla Básica
- **Monto mensual fijo**: $25 USD
- **Auto-reparto**: Si un usuario deposita ≥ $25, el sistema divide automáticamente en meses

### Ejemplos

#### Ejemplo 1: Depósito de $25
```
Entrada: $25
Resultado: 1 mes cubierto (mes actual)
Detalle auto-generado:
  - Marzo 2024: $25
```

#### Ejemplo 2: Depósito de $50
```
Entrada: $50
Resultado: 2 meses cubiertos
Detalle auto-generado:
  - Febrero 2024: $25
  - Marzo 2024: $25
```

#### Ejemplo 3: Depósito de $75
```
Entrada: $75
Resultado: 3 meses cubiertos
Detalle auto-generado:
  - Enero 2024: $25
  - Febrero 2024: $25
  - Marzo 2024: $25
```

#### Ejemplo 4: Depósito de $80
```
Entrada: $80
Resultado: 3 meses cubiertos + $5 sobrante
Detalle auto-generado:
  - Enero 2024: $25
  - Febrero 2024: $25
  - Marzo 2024: $25
Sobrante: $5 (puede acreditarse como crédito o rechazarse)
```

## 🔧 Implementación Técnica

### Archivo Modificado
- `admin/api/server.js`

### Nueva Función
```javascript
splitMonthlyDeposit(monto, fechaDeposito, config)
```

**Parámetros**:
- `monto`: Monto total depositado
- `fechaDeposito`: Fecha del depósito (para calcular meses retroactivos)
- `config`: Configuración del sistema

**Retorna**:
```javascript
{
  detalle: [
    { mes: 'enero', monto: 25, año: 2024 },
    { mes: 'febrero', monto: 25, año: 2024 },
    ...
  ],
  mesesCubiertos: 3,
  sobrante: 5.0,
  totalRepartido: 75.0
}
```

### Integración en Aprobación de Depósitos

El auto-reparto se ejecuta **automáticamente** cuando:
1. El depósito es de tipo `ahorro`
2. El monto es ≥ $25
3. No existe un `detalle` manual previo

```javascript
// En el endpoint POST /api/depositos/:id/aprobar
if (depTipo === 'ahorro' && monto >= 25) {
  const repartoResult = splitMonthlyDeposit(monto, depData?.fecha_deposito_detectada, config);
  if (repartoResult && repartoResult.detalle) {
    detalle = repartoResult.detalle.map(item => ({
      id_usuario: idUsuario,
      monto: item.monto,
      mes: item.mes,
      año: item.año
    }));
    
    // Guardar auditoría
    tx.update(depRef, {
      detalle_auto_generado: true,
      detalle_por_usuario: JSON.stringify(detalle),
      meses_cubiertos: repartoResult.mesesCubiertos,
      sobrante: repartoResult.sobrante
    });
  }
}
```

## ✅ Beneficios

### 1. **Evita Penalizaciones Incorrectas**
Antes, si un usuario pagaba $75 en marzo, el sistema veía:
- ❌ Un solo depósito de $75 en marzo
- ❌ Faltante de enero y febrero → multas injustas

Ahora, el sistema ve:
- ✅ Enero: $25 (cubierto)
- ✅ Febrero: $25 (cubierto)
- ✅ Marzo: $25 (cubierto)
- ✅ **Sin multas** porque todos los meses están pagados

### 2. **Transparencia Total**
- El campo `detalle_auto_generado: true` indica que fue un reparto automático
- El campo `meses_cubiertos` muestra cuántos meses se cubrieron
- El campo `sobrante` muestra si quedó dinero sin asignar

### 3. **Flexibilidad**
- Si el admin ya ingresó un detalle manual, **se respeta** (no se auto-reparte)
- Si el monto es < $25, se procesa como depósito simple sin reparto
- Depósitos de otros tipos (`plazo_fijo`, `certificado`, `pago_prestamo`) no se reparten

## 📊 Datos de Auditoría

Cuando se genera un auto-reparto, el documento del depósito incluye:

```javascript
{
  // ... otros campos del depósito ...
  detalle_auto_generado: true,
  detalle_por_usuario: "[{\"id_usuario\":\"abc123\",\"monto\":25,\"mes\":\"enero\",\"año\":2024}...]",
  meses_cubiertos: 3,
  sobrante: 5.0
}
```

## 🧪 Casos de Prueba

### Caso 1: Depósito Normal ($25)
```
POST /api/depositos/{id}/aprobar
Body: { "approve": true }

Depósito inicial:
  - monto: 25
  - tipo: ahorro
  - id_usuario: "user123"

Resultado:
  - 1 mes cubierto (mes actual)
  - Sin multas
  - total_ahorros += 25
```

### Caso 2: Pago Múltiple ($75)
```
POST /api/depositos/{id}/aprobar
Body: { "approve": true }

Depósito inicial:
  - monto: 75
  - tipo: ahorro
  - id_usuario: "user123"
  - fecha_deposito_detectada: "15/03/2024"

Resultado:
  - 3 meses cubiertos (enero, febrero, marzo)
  - detalle_auto_generado: true
  - meses_cubiertos: 3
  - Sin multas (todos los meses cubiertos)
  - total_ahorros += 75
```

### Caso 3: Depósito con Sobrante ($80)
```
POST /api/depositos/{id}/aprobar
Body: { "approve": true }

Depósito inicial:
  - monto: 80
  - tipo: ahorro

Resultado:
  - 3 meses cubiertos
  - sobrante: 5.0
  - Posible acción: acreditar $5 como crédito o rechazar depósito
```

## 🔒 Validaciones

1. **Monto mínimo**: Depósitos < $25 no se reparten (se procesan normalmente)
2. **Tipo de depósito**: Solo se reparten depósitos tipo `ahorro`
3. **Detalle manual**: Si ya existe un `detalle` manual, **no se sobreescribe**
4. **Sobrante**: Se registra pero no se auto-asigna (debe manejarse manualmente)

## 🚨 Importante

- Esta funcionalidad **solo afecta** depósitos de tipo `ahorro` con monto ≥ $25
- Depósitos de `plazo_fijo`, `certificado`, `pago_prestamo` se procesan como antes
- El sistema **NO elimina ni modifica** la funcionalidad de reparto manual existente

## 📝 Changelog

### v1.0.0 - 2024-12-13
- ✅ Implementada función `splitMonthlyDeposit()`
- ✅ Integrado auto-reparto en flujo de aprobación
- ✅ Agregados campos de auditoría (`detalle_auto_generado`, `meses_cubiertos`, `sobrante`)
- ✅ Actualizada documentación

## 🔗 Referencias

- Archivo: `admin/api/server.js` (líneas 592-640: función `splitMonthlyDeposit`)
- Archivo: `admin/api/server.js` (líneas 826-860: integración en aprobación)
- Configuración: Monto mensual fijo de $25 USD

---

**Autor**: Sistema de Caja de Ahorros  
**Fecha**: Diciembre 2024  
**Versión**: 1.0.0
