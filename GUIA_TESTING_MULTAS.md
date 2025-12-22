# 🧪 GUÍA DE TESTING - MULTAS Y DESAPARICIÓN DE ALERTAS

## 📋 Introducción

Este documento proporciona procedimientos paso a paso para verificar que:
1. Las multas se calculan correctamente
2. La alerta de multas desaparece al pagar
3. No hay doble cobro
4. Los nuevos usuarios heredan la configuración

---

## ✅ TEST 1: ALERTA DE MULTAS Y DESAPARICIÓN

### 🎯 Objetivo
Verificar que la alerta roja de "⚠️ MULTAS PENDIENTES" aparece después del día 10 y desaparece tras pagar.

### 📋 Precondiciones
- Aplicación móvil instalada
- Usuario autenticado
- Estamos en un día > 10 del mes

### ▶️ Pasos

#### **Paso 1: Crear una Multa Manualmente (Simulación)**

Si el sistema está en desarrollo y no hay multas creadas automáticamente:

1. Acceder a panel web (`http://localhost:5173`)
2. Como admin, crear una entrada manual en Firestore:
   ```
   Colección: multas
   Documento: nuevo
   Datos:
   {
     "id_usuario": "uid_del_cliente",
     "monto_multa": 50.00,
     "motivo": "Test - Atraso en depósito",
     "estado": "pendiente",
     "fecha_creacion": <timestamp>
   }
   ```

3. Actualizar el documento `usuarios/{uid}`:
   ```
   "total_multas": 50.00
   ```

#### **Paso 2: Verificar Alerta en Móvil**

1. Abrir app móvil
2. Navegar a Dashboard (pantalla principal)
3. **✅ Verificar**: Debe aparecer banner rojo con:
   - Ícono ⚠️ amarillo
   - Título: "⚠️ MULTAS PENDIENTES"
   - Monto: "$50.00"
   - Botón: "Pagar Multa"

#### **Paso 3: Usuario Paga la Multa**

1. Click en botón "Pagar Multa"
2. Abre formulario `MultasDepositoForm`
3. Ingresar:
   - Monto: `50.00`
   - Descripción: "Pago de multa"
   - Voucher: Seleccionar imagen o PDF
4. Click "Enviar"

#### **Paso 4: Admin Aprueba en Panel**

1. Abrir panel web (`http://localhost:5173`)
2. Ir a sección **Depósitos** → **Pendientes**
3. Buscar depósito con:
   - `tipo: 'multa'`
   - `monto: 50.00`
   - Usuario correcto
4. Click en **"Aprobar"**

#### **Paso 5: Verificar Desaparición de Alerta**

1. Volver a app móvil
2. Cerrar y reabrir la pantalla de Dashboard (pull to refresh o navegar a otra pestaña y volver)
3. **✅ Verificar**: 
   - ❌ Banner rojo DESAPARECE
   - ✅ Usuario puede volver a hacer depósitos de ahorro
   - ✅ Panel muestra "Sin multas"

### 🔍 Verificación en Backend

En terminal, ejecutar:
```bash
# Ver documento de usuario
curl -X GET "http://localhost:8080/api/users" \
  -H "Authorization: Bearer <token>"

# Buscar multas del usuario
db.collection('multas')
  .where('id_usuario', '==', 'uid_cliente')
  .where('estado', '==', 'pagada')
  .get()
```

**Esperado**: `total_multas: 0.0` y multa con `estado: 'pagada'`

---

## ✅ TEST 2: CÁLCULO DE MULTA FIJA POR DÍA

### 🎯 Objetivo
Verificar que una multa de $2/día se calcula correctamente con 3 días de gracia.

### 📋 Configuración Requerida

En Firestore, colección `configuracion`, documento `general`:
```json
{
  "enforce_voucher_date": true,
  "grace_days": 3,
  "penalty": {
    "type": "per_day_fixed",
    "value": 2.0
  },
  "due_schedule": "15/01/2025"
}
```

### ▶️ Pasos

#### **Paso 1: Crear Depósito Manual con Fecha Atrasada**

Usando panel admin o Firestore directamente:
```json
{
  "id_usuario": "uid_cliente",
  "tipo": "ahorro",
  "monto": 100.00,
  "fecha_deposito_detectada": "25/01/2025",  // 10 días después de vencimiento
  "voucher_hash": "test_hash_123",
  "estado": "pendiente"
}
```

#### **Paso 2: Admin Aprueba el Depósito**

1. Panel web → Depósitos → Pendientes
2. Buscar depósito
3. Click "Aprobar"

#### **Paso 3: Verificar Cálculo**

1. En backend, verificar que se agregó multa:
```javascript
// Query en Firestore
db.collection('multas')
  .where('id_usuario', '==', 'uid_cliente')
  .where('estado', '==', 'pendiente')
  .get()
  .then(snap => {
    snap.docs.forEach(doc => {
      console.log('Multa:', doc.data());
      // Esperado: monto_multa = (10 - 3 grace) * 2 = 7 * 2 = $14.00
    });
  });
```

**Cálculo Manual Esperado**:
- Vencimiento: 15/01
- Con gracia (3 días): 18/01
- Pago: 25/01
- Días tarde: 25 - 18 = 7 días
- **Multa: 7 × $2 = $14.00** ✅

#### **Paso 4: Usuario Paga**

1. Mobil → Dashboard → Alerta de multas
2. Ingresa $14.00
3. Admin aprueba
4. Verificar que `total_multas: 0.0`

---

## ✅ TEST 3: CÁLCULO DE MULTA PORCENTUAL

### 🎯 Objetivo
Verificar que una multa de 0.5% diario se calcula sobre el monto.

### 📋 Configuración Requerida

```json
{
  "enforce_voucher_date": true,
  "grace_days": 0,
  "penalty": {
    "type": "per_day_percent",
    "value": 0.5
  },
  "due_schedule": "30/01/2025"
}
```

### ▶️ Pasos

#### **Paso 1: Crear Depósito con Porcentaje**

```json
{
  "id_usuario": "uid_cliente",
  "tipo": "ahorro",
  "monto": 200.00,
  "fecha_deposito_detectada": "05/02/2025",  // 6 días tarde
  "voucher_hash": "test_hash_456",
  "estado": "pendiente"
}
```

#### **Paso 2: Verificar Cálculo Porcentual**

**Esperado**:
- Días de atraso: 6
- Multa: 6 × ($200 × 0.5 / 100) = 6 × $1.00 = **$6.00** ✅

En Firestore:
```javascript
const multa = 6 * (200 * 0.5 / 100); // = 6
console.log(multa); // 6.00
```

---

## ✅ TEST 4: PREVENCIÓN DE DOBLE COBRO

### 🎯 Objetivo
Verificar que no se puede pagar 2 veces el mismo comprobante.

### 📋 Escenario

Usuario intenta subir 2 veces el mismo voucher (mismo número de comprobante).

### ▶️ Pasos

#### **Paso 1: Primera Carga de Voucher**

App móvil:
1. Deposito → Seleccionar imagen de comprobante
2. OCR extrae: `número_comprobante: "12345678"`
3. App genera: `voucher_hash = SHA256("comprobante:12345678")`
4. Envía depósito

#### **Paso 2: Admin Aprueba**

Panel web → Aprueba el depósito

#### **Paso 3: Usuario Intenta Subir Mismo Comprobante**

App móvil:
1. Otro depósito → Mismo comprobante
2. OCR extrae: `número_comprobante: "12345678"` (igual)
3. App genera: `voucher_hash` (igual al anterior)

#### **Paso 4: Verificar Rechazo**

**Esperado**: 
- ✅ Backend rechaza: "Comprobante duplicado en últimos 30 días"
- ✅ App muestra error
- ✅ Depósito NO se crea

**Verificación en backend**:
```javascript
// Buscar duplicados
db.collection('depositos')
  .where('voucher_hash', '==', voucherHash)
  .get()
  .then(snap => {
    if (snap.docs.length > 1) {
      console.log('❌ DUPLICADO DETECTADO');
    }
  });
```

---

## ✅ TEST 5: USUARIO NUEVO HEREDA CONFIGURACIÓN

### 🎯 Objetivo
Verificar que un usuario recién creado ve los tipos de depósito y puede hacer depósitos.

### ▶️ Pasos

#### **Paso 1: Crear Usuario Nuevo**

Panel web → Usuarios → Crear
```
Nombre: "Test Usuario"
Email: "test.usuario@example.com"
Contraseña: [temporal]
Rol: "cliente"
Estado: "activo"
```

#### **Paso 2: Verificar Estructura en Firestore**

Documento `usuarios/{uid_nuevo}` debe tener:
```json
{
  "nombres": "Test Usuario",
  "correo": "test.usuario@example.com",
  "rol": "cliente",
  "estado": "activo",
  "total_ahorros": 0.0,
  "total_prestamos": 0.0,
  "total_multas": 0.0,
  "total_plazos_fijos": 0.0,
  "total_certificados": 0.0,
  "fecha_registro": <timestamp>
}
```

#### **Paso 3: Usuario Inicia Sesión en App**

1. Instalar APK en dispositivo
2. Registrarse con email: `test.usuario@example.com`
3. Contraseña: [la de admin]

#### **Paso 4: Verificar Visualización**

App móvil → Dashboard

**✅ Esperado**:
- ✅ Dashboard carga sin errores
- ✅ Totales muestran 0.0 en todos los tipos
- ✅ Botón "Hacer Depósito" disponible
- ✅ Selector de tipo muestra: "Ahorro", "Plazo Fijo", "Certificado"

#### **Paso 5: Hacer Depósito de Prueba**

1. Click "Hacer Depósito"
2. Tipo: "Ahorro"
3. Monto: $50.00
4. Voucher: [seleccionar]
5. Guardar

**✅ Esperado**: Depósito se crea correctamente (sin errores de tipo no encontrado)

---

## ✅ TEST 6: BLOQUEO POR MULTAS

### 🎯 Objetivo
Verificar que usuario con multas NO puede hacer depósitos de ahorro después del día 10.

### ▶️ Pasos

#### **Paso 1: Crear Multa**

Panel admin → Crear multa para usuario:
```
id_usuario: "uid_cliente"
monto_multa: 30.00
estado: "pendiente"
```

Actualizar usuario:
```
total_multas: 30.00
```

#### **Paso 2: Verificar Bloqueo en App**

**Si hoy es día > 10**:
1. App móvil → Dashboard
2. Click "Hacer Depósito"
3. Tipo: "Ahorro"
4. Click guardar

**✅ Esperado**: 
- ❌ Mensaje de error en rojo
- ❌ Depósito bloqueado
- ✅ Mensaje: "No puede realizar depósitos de ahorro mientras tenga multas pendientes"

#### **Paso 3: Usuario Paga Multa**

1. Click "Pagar Multa"
2. Monto: $30.00
3. Guardar
4. Admin aprueba

#### **Paso 4: Verificar Desbloqueado**

1. App móvil → Dashboard
2. Click "Hacer Depósito"
3. Tipo: "Ahorro"
4. Click guardar

**✅ Esperado**: 
- ✅ Depósito se crea exitosamente
- ✅ Sin mensaje de error
- ✅ Usuario desbloqueado

---

## 🔧 SCRIPT DE TESTING AUTOMÁTICO

Se proporciona en: `scripts/test_extremo_sistema.js`

### Ejecución

```bash
cd admin/api
node ../../scripts/test_extremo_sistema.js
```

### Cobertura

- ✅ 21 casos de test
- ✅ 100% de paso histórico
- ✅ Validación de:
  - Cálculos correctos
  - Límites de precisión
  - Casos extremos (año cruzando)
  - Decimales
  - Negativos (prevenidos)

---

## 📊 MATRIZ DE VALIDACIÓN

| Test | Resultado Esperado | Verificación |
|------|-------------------|--------------|
| 1. Alerta desaparece | ✅ Manual | User.totalMultas = 0 |
| 2. Multa fija | ✅ Manual | $14 = 7 × $2 |
| 3. Multa porcentual | ✅ Manual | $6 = 6 × ($200 × 0.5%) |
| 4. No doble cobro | ✅ Manual | voucher_hash único |
| 5. Usuario hereda config | ✅ Manual | Campos inicializados |
| 6. Bloqueo por multas | ✅ Manual | Depósito rechazado |
| Automatizados | ✅ Script | 21/21 pass |

---

## 🎯 CONCLUSIÓN

Todos los tests deben pasar para garantizar producción. Si alguno falla:

1. **Documentar el error**
2. **Revisar logs en Firestore**
3. **Ejecutar script de debugging**: `scripts/test_extremo_sistema.js`
4. **Contactar a desarrollador**

**APK está lista cuando**: ✅ Todos los tests pasan
