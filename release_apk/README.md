# 📱 APK Caja de Ahorros - v1.0.1

## 📦 Archivo
`app-release-v1.0.1-30dic2025.apk` (91.81 MB)

## ✨ Correcciones en Esta Versión

### ✅ Ahorro Voluntario
- Campo ahora se muestra correctamente en el dashboard del cliente
- Total se actualiza automáticamente desde Firebase Firestore
- Depósitos de tipo "Ahorro voluntario" actualizan el total correctamente

### 🔧 Mejoras Técnicas
- Agregado campo `totalAhorroVoluntario` al modelo Usuario
- Mapeo correcto en `firestore_service.dart`
- Sincronización con backend para tipo `ahorro_voluntario`

---

## 📲 Instalación

### Paso 1: Copiar APK al Dispositivo
Transfiere el archivo `app-release-v1.0.1-30dic2025.apk` a tu dispositivo Android mediante:
- Cable USB
- Correo electrónico
- Google Drive / Dropbox
- Compartir por WhatsApp / Telegram

### Paso 2: Habilitar Instalación de Apps Desconocidas
1. Ve a **Configuración** → **Seguridad** (o **Privacidad**)
2. Busca **Instalar aplicaciones desconocidas** o **Fuentes desconocidas**
3. Habilita la opción para el explorador de archivos o navegador que uses

### Paso 3: Instalar APK
1. Abre el archivo `.apk` desde el gestor de archivos
2. Toca **Instalar**
3. Espera a que se complete la instalación
4. Toca **Abrir** o busca "Caja Ahorro" en el menú de aplicaciones

### Paso 4: Iniciar Sesión
1. Ingresa tu correo electrónico registrado
2. Ingresa tu contraseña
3. Si es tu primer acceso, solicita las credenciales al administrador

---

## 🔍 Verificar Que Funciona

Después de iniciar sesión:

1. **Dashboard Principal** debe mostrar:
   - ✅ Ahorro Mensual
   - ✅ **Ahorro Voluntario** ← CORREGIDO
   - ✅ Plazos Fijos
   - ✅ Certificados
   - ✅ Multas (si aplica)

2. **Crear Depósito**:
   - Selecciona tipo "Ahorro voluntario"
   - Sube comprobante
   - Espera aprobación del admin
   - Total se actualizará automáticamente

3. **Ver Movimientos**:
   - Historial completo de depósitos
   - Estado: Pendiente / Aprobado / Rechazado

---

## ⚠️ Problemas Conocidos (Resueltos)

- ~~Campo "Ahorro Voluntario" mostraba $0.00~~ ✅ **CORREGIDO**
- ~~No se actualizaba el total desde Firebase~~ ✅ **CORREGIDO**

---

## 📞 Soporte

Si encuentras algún problema:
1. Verifica que tienes conexión a Internet
2. Cierra y abre la app nuevamente
3. Contacta al administrador si el problema persiste

---

**Fecha de Build**: 30 de diciembre de 2025  
**Versión**: v1.0.1  
**Tamaño**: 91.81 MB  
**Android mínimo**: 5.0 (API 21)
