# 🚀 Guía Rápida de Prueba - Sistema de Multas

## ✅ Para Probar HOY (13 de diciembre)

### 1. Ejecutar la App

```powershell
cd C:\Users\trave\app_cajaAhorros\caja_ahorro_app
flutter run
```

### 2. Escenario de Prueba: Multa por Ahorro Faltante

#### Condiciones:
- Hoy es **13 de diciembre** (día > 10) ✅
- Usuario NO tiene depósito de "ahorro" aprobado en diciembre

#### Pasos:
1. **Iniciar sesión** con un usuario que NO tenga ahorro de diciembre
2. **Esperar 2-3 segundos** (el servicio verifica multas automáticamente)
3. **Observar el dashboard:**
   - ¿Aparece banner rojo con "⚠️ MULTAS PENDIENTES"?
   - ¿Muestra el monto de la multa?
   - ¿Tiene botón "PAGAR MULTAS AHORA"?

#### Resultado Esperado:
```
BANNER ROJO:
⚠️ MULTAS PENDIENTES
Tienes multas por pagar: $3.00
No podrás realizar depósitos de ahorro mensual ni pagos de préstamo...
[PAGAR MULTAS AHORA]
```

**Cálculo de la multa:**
- Día 13 de diciembre
- Días tarde: 13 - 10 = 3 días
- Semanas: ((3 - 1) / 7) + 1 = 1 semana
- Multa: 1 semana × $1.00 = **$1.00**

> **Nota:** Si ya tienes un depósito de ahorro aprobado en diciembre, NO verás multa.

---

### 3. Escenario de Prueba: Bloqueo de Opciones

#### Condiciones:
- Usuario tiene multa pendiente ($1.00 o más)
- Hoy es día > 10

#### Pasos:
1. **Desde el dashboard**, ir a "Nuevo Depósito"
2. **Observar el formulario:**
   - ¿Aparece tarjeta naranja de advertencia?
   - ¿"Ahorro (mensual)" está en gris con icono ⛔?
   - ¿"Pago préstamo" está en gris con icono ⛔?

3. **Intentar seleccionar "Ahorro (mensual)"**
4. **Llenar el formulario** y tocar "Guardar"

#### Resultado Esperado:
```
❌ ERROR (SnackBar rojo):
"⚠️ No puede realizar depósitos de ahorro mensual ni pago de préstamos 
mientras tenga multas pendientes. Por favor, pague sus multas primero."
```

---

### 4. Verificar en Firestore

#### Abrir Firebase Console:
https://console.firebase.google.com/

#### Verificar Colecciones:

**1. Colección `multas`:**
```javascript
multas/{documentId}
{
  "id_usuario": "TU_UID",
  "monto": 1.0,
  "motivo": "Falta de ahorro mensual - 12/2025",
  "tipo": "ahorro_faltante",
  "fecha_aplicacion": Timestamp,
  "mes": 12,
  "anio": 2025,
  "estado": "pendiente"
}
```

**2. Colección `movimientos`:**
```javascript
movimientos/{documentId}
{
  "tipo": "multa",
  "id_usuario": "TU_UID",
  "monto": 1.0,
  "descripcion": "Falta de ahorro mensual - 12/2025",
  "fecha": Timestamp,
  "mes": 12,
  "anio": 2025
}
```

**3. Colección `users/{tu_uid}`:**
```javascript
{
  "total_multas": 1.0  // Debe estar actualizado
}
```

---

## 🧪 Pruebas Adicionales

### Caso 1: Usuario CON ahorro del mes
```
✅ Resultado: NO aparece banner de multas
✅ Todas las opciones de depósito disponibles
```

### Caso 2: Usuario SIN multas antes del día 10
```
✅ Resultado: NO aparece banner
✅ Todas las opciones disponibles
```

### Caso 3: Pagar la multa
```
1. Tocar botón "PAGAR MULTAS AHORA"
2. Ir al formulario de multas
3. Ingresar monto = $1.00
4. Subir comprobante
5. Guardar
6. Admin aprueba el pago
7. Verificar:
   ✅ total_multas vuelve a $0.00
   ✅ Banner desaparece
   ✅ Opciones desbloqueadas
```

---

## 🔍 Debug y Logs

### Ver logs de la app:
```powershell
# En la terminal donde corre flutter run
# Buscar mensajes como:
# "Verificando multas para usuario..."
# "Multa aplicada: $1.00"
```

### Si NO aparece la multa:

1. **Verificar fecha del dispositivo:**
   ```dart
   // ¿Es > día 10?
   DateTime.now().day > 10
   ```

2. **Verificar depósitos:**
   ```javascript
   // En Firestore, ir a depositos
   // Filtrar por:
   // - id_usuario = TU_UID
   // - tipo = "ahorro"
   // - estado = "aprobado"
   // - fecha_deposito en diciembre 2025
   ```

3. **Verificar configuración:**
   ```javascript
   // En Firestore:
   config/configuracion_general
   {
     "enforce_voucher_date": true  // DEBE ser true
   }
   ```

---

## 📱 Comandos Útiles

### Compilar APK para distribución:
```powershell
flutter build apk --release
```

### Limpiar y reconstruir:
```powershell
flutter clean
flutter pub get
flutter run
```

### Ver errores de Firestore:
```powershell
# En la consola de debug, habilitar logs de Firestore
```

---

## ✅ Checklist de Validación

- [ ] Banner rojo aparece cuando hay multa y día > 10
- [ ] Monto de multa es correcto ($1.00 para día 13)
- [ ] Opciones "Ahorro mensual" y "Pago préstamo" bloqueadas
- [ ] Tarjeta naranja de advertencia visible en formulario
- [ ] Error al intentar guardar depósito bloqueado
- [ ] Multa registrada en colección `multas`
- [ ] Movimiento registrado en colección `movimientos`
- [ ] Campo `total_multas` actualizado en `users`
- [ ] Botón "PAGAR MULTAS AHORA" funcional
- [ ] Después de pagar, opciones se desbloquean

---

## 🐛 Problemas Comunes

### Problema: Banner no aparece
**Solución:**
1. Cerrar sesión y volver a iniciar
2. Verificar que `total_multas` > 0 en Firestore
3. Verificar que hoy es día > 10

### Problema: Opciones no se bloquean
**Solución:**
1. Refrescar la página del formulario
2. Verificar que `_hasMultas` es true
3. Verificar que `_esDepuesDiaDiez` es true

### Problema: Multa no se registra
**Solución:**
1. Verificar conexión a internet
2. Verificar permisos de Firestore
3. Revisar reglas de seguridad de Firestore

---

## 📞 Soporte

Si algo no funciona como se espera:

1. **Capturar pantalla** del error
2. **Revisar logs** de la consola Flutter
3. **Verificar Firestore** manualmente
4. **Compartir información** del problema

---

**¡Listo para probar!** 🎉

Inicia sesión con un usuario que NO tenga ahorro de diciembre y verifica que el sistema aplica la multa automáticamente.
