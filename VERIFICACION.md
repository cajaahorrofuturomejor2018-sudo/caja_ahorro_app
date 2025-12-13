# ✅ VERIFICACIÓN DE CAMBIOS - WEB ADMIN Y APK

## 🖥️ PANEL WEB ADMIN - VERIFICAR CAMBIOS

### Acceso
**URL:** http://localhost:5173

### 1️⃣ Tab PRÉSTAMOS - Nuevas Funcionalidades

#### ✅ Para préstamos PENDIENTES:
1. Clic en botón **"✓ Revisar"**
2. **Verificar modal de aprobación:**
   - ✅ Campo "Monto a Aprobar"
   - ✅ Campo "Interés Anual (%)"
   - ✅ Campo "Plazo (meses)"
   - ✅ **Sección amarilla "Contrato de Préstamo (PDF) *Obligatorio"**
   - ✅ Input para seleccionar archivo PDF
   - ✅ Botón "⬆️ Subir PDF"
   - ✅ **CRÍTICO:** Botón "Aprobar" debe estar deshabilitado si NO hay PDF subido
3. **Probar flujo completo:**
   - Seleccionar un PDF
   - Clic en "Subir PDF"
   - Esperar mensaje "✅ PDF subido correctamente"
   - Clic en "✅ Aprobar Préstamo"
   - Verificar mensaje de éxito

#### ✅ Para préstamos ACTIVOS:
1. **Buscar préstamo con estado "Activo"**
2. **Verificar nuevos botones:**
   - ✅ Botón azul **"📋 Revisar"** (NUEVO)
   - ✅ Botón naranja "⚡ Precancelar" (ya existía)

3. **Clic en "📋 Revisar"**
4. **Verificar modal completo con:**
   - ✅ Detalles del préstamo (monto, saldo, cuota, interés, plazo)
   - ✅ Sección azul con enlace "📄 Contrato: Ver PDF"
   - ✅ Tabla "Historial de Pagos" (si hay pagos previos)
   - ✅ Sección amarilla "💰 Registrar Pago"
   - ✅ Campo "Monto (S/)"
   - ✅ Campo "Descripción (opcional)"
   - ✅ Botón verde "✅ Registrar Pago"

5. **Probar registro de pago:**
   - Ingresar monto: `100.00`
   - Descripción: `Cuota diciembre 2025`
   - Clic en "Registrar Pago"
   - Verificar mensaje de éxito
   - Modal debe cerrarse
   - Recargar página y verificar que el saldo pendiente disminuyó

### 2️⃣ Tab DEPÓSITOS - Nueva Columna

#### ✅ Verificar tabla de depósitos:
1. Ir a tab **"💰 Depósitos"**
2. **Verificar columnas en la tabla:**
   - Usuario
   - Fecha
   - Monto
   - Tipo
   - **Voucher** ⬅️ NUEVA COLUMNA
   - Estado
   - Acciones

3. **En columna "Voucher" verificar:**
   - ✅ Si hay archivo: Link "🖼️ Ver Imagen" o "📄 Ver PDF"
   - ✅ Si NO hay archivo: Texto gris "Sin archivo"

4. **Clic en link de voucher:**
   - Debe abrir en nueva pestaña
   - Debe mostrar imagen/PDF del comprobante

### 3️⃣ Tab CAJA

#### ✅ Verificar actualización automática:
1. Ir a tab **"Caja - Control de Saldo"**
2. **Anotar saldo actual**
3. **Volver a DEPÓSITOS**
4. **Aprobar un depósito pendiente**
5. **Volver a CAJA**
6. **Verificar que el saldo aumentó** por el monto del depósito

---

## 📱 APP MÓVIL FLUTTER - VERIFICAR CAMBIOS

### Conectar dispositivo y ejecutar:
```bash
# Ver dispositivos
flutter devices

# Ejecutar en dispositivo (reemplazar ID)
flutter run -d 6583eb20

# O compilar APK
flutter build apk --release
```

### 1️⃣ Dashboard - Multas

#### ✅ Verificar banner de multas:
1. **Login con usuario que tenga multas**
2. **Si hoy es después del día 10:**
   - ✅ Debe aparecer banner rojo arriba: "⚠️ Tiene multas pendientes"
   - ✅ Card "Multas Pendientes" con monto total
3. **Clic en "Pagar Multas"**
4. **Verificar formulario de pago de multas**
5. **Registrar pago con voucher**
6. **Al regresar al dashboard:**
   - ✅ Banner de multas debe desaparecer
   - ✅ Total de multas debe ser S/ 0.00

### 2️⃣ Depósitos - Validación de Multas

#### ✅ Probar bloqueo por multas (después del día 10):
1. **Usuario CON multas pendientes**
2. **Intentar registrar:**
   - Depósito de "Ahorro Mensual"
   - O "Pago de Préstamo"
3. **Debe mostrar alerta roja:**
   > "⚠️ No puede realizar depósitos de ahorro mensual ni pago de préstamos mientras tenga multas pendientes. Por favor, pague sus multas primero."
4. **Formulario NO debe permitir guardar**

#### ✅ Sin multas o depósito permitido:
1. **Usuario SIN multas**
2. **Poder registrar cualquier tipo de depósito**

### 3️⃣ Préstamos - Solicitud

#### ✅ Formulario de préstamo:
1. **Ir a "Solicitar préstamo"**
2. **Llenar formulario:**
   - Monto: `5000`
   - Tipo: Consumo/Personal/Hipotecario
   - Plazo: `12` meses
3. **Upload de certificado (opcional)**
4. **Enviar solicitud**
5. **Verificar en "Mis préstamos":**
   - ✅ Estado: "Pendiente"
   - ✅ Monto solicitado correcto
   - ✅ Plazo correcto

---

## 🤖 GITHUB ACTIONS - CI/CD

### Verificar workflow automático:

1. **Ir a:** https://github.com/cajaahorrofuturomejor2018-sudo/caja_ahorro_app/actions

2. **Buscar workflow:** "Build and Release APK"

3. **Debe estar ejecutándose** (badge amarillo 🟡) o **completado** (badge verde ✅)

4. **Si completó exitosamente:**
   - Ir a: https://github.com/cajaahorrofuturomejor2018-sudo/caja_ahorro_app/releases
   - **Verificar nueva release creada**
   - **Verificar archivos adjuntos:**
     - ✅ `caja-ahorros-vX.X.X-buildXXX.apk`
     - ✅ `caja-ahorros-vX.X.X-buildXXX.aab`

5. **Descargar APK desde releases**

6. **Instalar en dispositivo Android:**
   ```
   1. Descargar APK
   2. Habilitar "Orígenes desconocidos"
   3. Instalar APK
   4. Abrir app
   5. Verificar todas las funcionalidades
   ```

---

## 🐛 Troubleshooting

### Web Admin no muestra cambios:
```bash
cd admin
docker compose down
docker compose build --no-cache
docker compose up -d
```

### APK no se compila en GitHub:
1. Verificar que los tests pasen localmente: `flutter test`
2. Revisar logs del workflow en GitHub Actions
3. Verificar que `pubspec.yaml` tenga versión válida

### Contenedores no inician:
```bash
docker compose logs api
docker compose logs web
docker ps -a
```

### App Flutter no conecta con backend:
1. Verificar que Firebase esté configurado
2. Verificar `google-services.json` en `android/app/`
3. Ejecutar `flutterfire configure`

---

## ✅ CHECKLIST COMPLETO

### Web Admin
- [ ] Modal de aprobación de préstamo con upload PDF obligatorio
- [ ] Botón "Revisar" en préstamos activos funciona
- [ ] Modal de revisión muestra detalles, contrato e historial
- [ ] Formulario de registro de pagos funciona
- [ ] Columna "Voucher" visible en tabla de depósitos
- [ ] Links a imágenes/PDF de vouchers funcionan
- [ ] Caja se actualiza al aprobar depósitos
- [ ] Caja se actualiza al registrar pagos

### App Flutter
- [ ] Banner de multas visible después del día 10
- [ ] Formulario de pago de multas funciona
- [ ] Dashboard se refresca al pagar multas
- [ ] Bloqueo de depósitos por multas funciona
- [ ] Solicitud de préstamos funciona
- [ ] Visualización de préstamos en "Mis préstamos"

### Backend
- [ ] Endpoint `/api/prestamos/:id/approve` valida PDF
- [ ] Endpoint `/api/prestamos/:id/pagos` actualiza caja
- [ ] Endpoint `/api/prestamos/:id/precancelar` actualiza caja
- [ ] Endpoint `/api/deposits/:id/approve` limpia multas
- [ ] Todas las transacciones actualizan caja correctamente

### CI/CD
- [ ] Workflow ejecutándose en GitHub Actions
- [ ] APK publicada en Releases
- [ ] README tiene enlace de descarga
- [ ] Documentación DESCARGAR_APK.md disponible

---

**Fecha de verificación:** 13 de diciembre de 2025
**Versión:** v1.0.0
**Branch:** fix/deposito-reparto
