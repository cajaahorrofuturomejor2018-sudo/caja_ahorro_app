// Configuración de emulador usada sólo en modo debug.
//
// Para probar desde un dispositivo físico, sustituye `null` por la IP de tu PC en la
// red local (p. ej. '192.168.1.42'). Si usas un emulador Android AVD deja `null`
// y el `main.dart` usará 10.0.2.2 por defecto.

/// IP del host donde corre el Firebase Emulator Suite (o `null` para usar el
/// comportamiento por defecto: AVD 10.0.2.2).
const String? kEmulatorHostOverride = null;
