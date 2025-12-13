# Configuración nativa necesaria (Firebase, ML Kit, JDK 21)

Este documento resume los pasos mínimos para dejar la app lista en Android e iOS.

## Firebase (Android)
1. En la consola de Firebase crea un proyecto y añade una app Android con el package name `com.example.caja_ahorro_app` (o tu propio applicationId).
2. Descarga `google-services.json` y cópialo en `android/app/google-services.json`.
3. En el `android/build.gradle` (root) aplica el plugin Google Services si no está:
   - Añade `classpath 'com.google.gms:google-services:4.4.4'` en `buildscript` dependencies o en el plugin management según tu setup.
4. En `android/app/build.gradle` añade al final: `apply plugin: 'com.google.gms.google-services'`.
5. Verifica que `minSdkVersion` sea compatible (>=21 recomendado para ML Kit y algunos plugins).

## Firebase (iOS)
1. Descarga `GoogleService-Info.plist` desde la consola de Firebase y colócalo en `ios/Runner/`.
2. Abre `ios/Runner.xcworkspace` en Xcode y confirma que el archivo esté incluido en el target Runner.
3. Ejecuta `pod install` desde `ios/` si es necesario (Flutter normalmente lo hace automat.).

## ML Kit (google_mlkit_text_recognition)
- Ya se añadió la dependencia `google_mlkit_text_recognition`.
- Android: no requiere cambios adicionales en Gradle salvo minSdk y permisos (ya añadidos en `AndroidManifest.xml`).
- iOS: la dependencia usa CocoaPods; si hay problemas, ejecuta `pod repo update` y `pod install`.

## Permisos
- Android: `android/app/src/main/AndroidManifest.xml` debe tener:
  ```xml
  <uses-permission android:name="android.permission.CAMERA" />
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
  ```
- iOS: `ios/Runner/Info.plist` ya incluye `NSCameraUsageDescription` y `NSPhotoLibraryUsageDescription`.

## JDK 21 (opcional — para usar Java 21 con Gradle)
Si quieres que Gradle use JDK 21 localmente (ej.: para compilar con características o compatibilidad específica):

1. Instala Temurin/Adoptium JDK 21 en Windows. Ejemplo con enlace (descarga manual):
   - https://adoptium.net/
2. Después de instalar, configura `org.gradle.java.home` en `android/gradle.properties` apuntando al path del JDK (sin la carpeta `bin`). Ejemplo en Windows:
   ```properties
   org.gradle.java.home=C:\\Program Files\\Eclipse Adoptium\\jdk-21.0.0.0-hotspot
   ```
3. O establece la variable de entorno `JAVA_HOME` al JDK 21 y reinicia la terminal.
4. Comprueba con `cd android && gradlew.bat -v` que la JVM usada es la 21.

### Verificación rápida
Puedes usar el script incluido `scripts/check-jdk21.ps1` para comprobar localmente si Java 21 está instalado y para ver si Gradle lo está usando. Desde la raíz del repositorio ejecuta:

```powershell
.\scripts\check-jdk21.ps1
```

## Notas adicionales
- Si añades `printing` o `share_plus`, revisa permisos en Android si usas almacenamiento externo.
- Para producción, configura ProGuard/R8 (minify) y reglas para ML Kit si usas ofuscación.
- Si encuentras errores nativos, comparte el log de `flutter run -v` para diagnosticar.

Si quieres, puedo generar los comandos exactos para la instalación de Temurin/JDK 21 en Windows y actualizar `android/gradle.properties` con una línea comentada que indique la ruta sugerida.