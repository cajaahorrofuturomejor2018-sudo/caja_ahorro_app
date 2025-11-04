# Guía de preparación para actualizar a Java 21 (Android / Flutter)

Este documento explica los pasos seguros y manuales para actualizar el entorno Android del proyecto a Java 21. No ejecuta cambios automáticos al código del proyecto; las instrucciones están pensadas para que las sigas localmente y verifiques la compatibilidad.

1) Instalar JDK 21 en Windows

- Descarga una distribución del JDK 21 (Eclipse Adoptium, Temurin, Liberica, Azul, etc.). Ejemplo con Adoptium:

  - Ve a https://adoptium.net/ y selecciona Temurin 21 (Windows x64) y descárgalo.
  - Instala en una ruta como `C:\Program Files\Java\jdk-21`.

2) Apuntar Gradle a tu JDK (opcionalmente por proyecto)

- Puedes fijar la variable `org.gradle.java.home` en `android/gradle.properties` o en `gradle.properties` a nivel usuario. Ejemplo (PowerShell):

```powershell
# Edita android/gradle.properties y añade (o actualiza):
org.gradle.java.home=C:\\Program Files\\Java\\jdk-21
```

3) Compatibilidad de Android Gradle Plugin (AGP) y Gradle

- Java 21 requiere versiones recientes de Gradle y AGP. Antes de forzar la actualización, comprueba:
  - Gradle wrapper (archivos `gradle/wrapper/gradle-wrapper.properties`) — actualiza Gradle a una versión que soporte toolchains y Java 21 (por ejemplo Gradle 8.5+ o la recomendada por AGP que uses).
  - Android Gradle Plugin (archivo `android/build.gradle.kts` o `build.gradle`) — usa una versión de AGP compatible con tu Gradle y Java.

4) Cambios en `android/app/build.gradle.kts` y `android/build.gradle.kts`

- Si decides actualizar el proyecto, estos son los ajustes mínimos (ejemplo en Kotlin DSL):

```kotlin
android {
  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
  }

  kotlinOptions {
    jvmTarget = "21"
  }
}
```

5) Pruebas y pasos recomendados

- Antes de cambiar `kotlinOptions.jvmTarget` a `21`, asegúrate de que:
  - Todos los módulos y librerías (plugins de Gradle, dependencias nativas) soportan Java 21.
  - Las herramientas CI/entorno de compilación tienen JDK 21 instalado.

- Ejecuta en PowerShell:

```powershell
# limpiar y compilar
flutter clean; flutter pub get; flutter build apk --release -v
```

6) Si quieres que yo aplique cambios mínimos al repositorio (comentados) lo puedo hacer, pero los pasos que alteran JDK local no se pueden ejecutar desde aquí: debes instalar el JDK 21 y/o indicarme la ruta exacta si quieres que inserte `org.gradle.java.home` en `gradle.properties`.

7) Notas finales

- Recomendación: haz estos cambios en una rama nueva, ejecuta la build en un emulador/CI y verifica. Si surge algún error, puedo ayudarte a interpretar los logs y proponer correcciones (actualizar versiones de plugins, migrar llamadas obsoletas, etc.).

---

Cambios aplicados por el asistente
---------------------------------

He actualizado en el repositorio los ajustes de compilación mínimos para apuntar a Java 21:

- En `android/app/build.gradle.kts`:
  - `compileOptions.sourceCompatibility` y `compileOptions.targetCompatibility` cambiados de `JavaVersion.VERSION_11` a `JavaVersion.VERSION_21`.
  - `kotlinOptions.jvmTarget` cambiado de `"11"` a `"21"`.

Qué debes hacer después
-----------------------

- Instala JDK 21 localmente (por ejemplo Temurin/Adoptium) en tu máquina: `C:\Program Files\Java\jdk-21`.
- Comprueba que Gradle usa JDK 21: desde `android` ejecuta `gradlew.bat -v` o ajusta `org.gradle.java.home` en `android/gradle.properties` con la ruta de tu JDK 21.
- Ejecuta `flutter clean; flutter pub get; flutter build apk --release -v` y revisa errores. Si algo falla por incompatibilidad de AGP/Gradle, te ayudo a actualizar esas versiones.

Si quieres, puedo también:

- Descomentar/establecer `org.gradle.java.home` en `android/gradle.properties` con una ruta que me indiques.
- Actualizar el Gradle wrapper o el Android Gradle Plugin si la build fallara por compatibilidad.

Nota: no puedo instalar JDK en tu máquina desde aquí ni ejecutar builds que dependan del JDK instalado localmente; por eso es importante que confirmes la instalación de JDK 21 y la ruta si quieres que deje la configuración fija en el repo.
