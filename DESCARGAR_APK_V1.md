# 📱 Descargar APK de Caja de Ahorro

## ✅ Versión Disponible

**v1.0.0-beta.1** - Compilada: 13 de diciembre de 2025

### 📥 Descargar

[👉 **Descargar APK desde GitHub Releases**](https://github.com/cajaahorrofuturomejor2018-sudo/caja_ahorro_app/releases/tag/v1.0.0-beta.1)

---

## 🔧 Instalación en tu Dispositivo Android

### Requisitos
- Android 6.0 o superior (API nivel 21+)
- Espacio disponible: ~100 MB
- Conexión a internet

### Pasos de Instalación

#### Opción 1: Desde Email o WhatsApp

1. **Descargar archivo**
   - Descarga el archivo `app-release.apk` desde el enlace de arriba
   - Se guardará en tu carpeta de Descargas

2. **Habilitar instalación desde fuentes desconocidas**
   - Abre **Configuración** → **Seguridad**
   - Busca "Instalar apps desconocidas" o "Fuentes desconocidas"
   - Habilita esta opción

3. **Instalar**
   - Abre el Administrador de Archivos
   - Navega a **Descargas**
   - Toca el archivo `app-release.apk`
   - Selecciona **Instalar**
   - Espera a que finalice

#### Opción 2: Mediante USB (Desde Computadora)

1. Conecta tu dispositivo Android a la computadora con USB
2. En la computadora:
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

---

## 🎯 Características Incluidas en v1.0.0-beta.1

✅ **Gestión de Depósitos**
- Crear depósitos de ahorros
- Gestionar depósitos a plazo fijo
- Subir vouchers de comprobante

✅ **Gestión de Préstamos**
- Solicitar préstamos
- Registrar pagos
- Ver estado de préstamos activos

✅ **Depósitos de Multas**
- Registrar pagos de multas
- Control automático de penalidades

✅ **Panel de Administrador (Web)**
- Aprobar/rechazar depósitos
- Validar documentos PDF (plazos fijos)
- Establecer interés para cada depósito
- Revisar préstamos y pagos
- Visualizar vouchers directamente

✅ **Características Nuevas**
- Modal de aprobación para plazos fijos con interés % y PDF
- Visor de vouchers mejorado con preview inline
- Validación mejorada de documentos

---

## ⚠️ Notas Importantes

- Esta es una **versión beta**. Puede contener bugs
- Se recomienda hacer backup de datos importantes
- Requiere conexión a internet para sincronizar con Firebase
- La app usará tu información de Google/correo electrónico para autenticarse

---

## 🐛 Reportar Problemas

Si encuentras algún bug o tienes sugerencias:
1. Abre un [issue en GitHub](https://github.com/cajaahorrofuturomejor2018-sudo/caja_ahorro_app/issues)
2. Describe el problema detalladamente
3. Incluye capturas de pantalla si es posible

---

## 📋 Historial de Cambios

### v1.0.0-beta.1 (13/12/2025)

**Nuevas Características:**
- Modal de aprobación para depósitos (plazos fijos/certificados)
- Validación de interés % obligatorio
- Validación de documento PDF obligatorio
- Visor de vouchers mejorado con preview inline
- Backend actualizado para guardar interés y documento

**Correcciones:**
- Sincronización correcta de saldo de caja
- Validación mejorada de transacciones
- Mejor manejo de errores

---

## ❓ Preguntas Frecuentes

**P: ¿Necesito compilar el APK yo mismo?**
A: No, puedes descargarlo directamente de las Releases.

**P: ¿Es seguro instalar APK de terceros?**
A: Sí, siempre que descargues de fuente confiable (este GitHub).

**P: ¿Qué datos se almacenan?**
A: Los datos se sinconizan con Firebase. No se almacenan datos en el dispositivo.

**P: ¿Puedo desinstalar la app y reinstalarla sin perder datos?**
A: Sí, los datos se recuperarán al iniciar sesión nuevamente.

---

## 📞 Soporte

Para soporte técnico, contacta al administrador de la aplicación.

**Última actualización:** 13 de diciembre de 2025
