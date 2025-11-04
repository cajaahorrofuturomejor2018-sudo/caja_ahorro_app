class Validators {
  static String? validarCorreo(String? value) {
    if (value == null || value.isEmpty) return "Ingrese un correo electrónico";
    final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegExp.hasMatch(value)) return "Correo no válido";
    return null;
  }

  static String? validarPassword(String? value) {
    if (value == null || value.isEmpty) return "Ingrese una contraseña";
    if (value.length < 6) return "Debe tener al menos 6 caracteres";
    return null;
  }

  static String? validarTexto(String? value, String campo) {
    if (value == null || value.isEmpty) return "Ingrese $campo";
    return null;
  }
}
