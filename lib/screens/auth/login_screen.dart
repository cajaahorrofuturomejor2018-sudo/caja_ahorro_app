// ignore_for_file: deprecated_member_use
// LoginScreen rediseñado: tarjeta central, gradiente, logo, campos con iconos y CTA
import 'package:flutter/material.dart';
import '/core/services/auth_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Activa temporalmente el proveedor DEBUG de App Check (si es aplicable),
  /// solicita el token forzando refresh, lo guarda en disco y devuelve el token.

  /// Después de un login exitoso, ejecutar diagnósticos para detectar
  /// problemas de App Check / Firestore / FCM que puedan impedir el uso
  /// en otro dispositivo. Muestra mensajes claros en pantalla.
  Future<void> _postLoginDiagnostics(User user) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Intentar obtener token FCM
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        fcmToken = 'ERROR_OBTENER_FCM: $e';
      }

      // Intentar leer el documento de usuario en Firestore para validar permisos
      try {
        final doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .get();
        if (!doc.exists) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Diagnóstico: documento de usuario no encontrado.'),
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Diagnóstico: lectura de Firestore OK.'),
            ),
          );
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error leyendo Firestore: ${e.toString()}')),
        );
      }

      // Mostrar token FCM (diagnóstico local)
      if (fcmToken != null) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'FCM token: ${fcmToken.length > 30 ? '${fcmToken.substring(0, 30)}...' : fcmToken}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error diagnóstico: ${e.toString()}')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _checkFirstRun();
  }

  Future<void> _checkFirstRun() async {
    try {
      // No-op: App Check debug token flow has been removed.
    } catch (_) {
      // ignore - non critical
    }
  }

  Future<void> _tryLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);

    try {
      final user = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (user != null) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Inicio de sesión correcto')),
        );
        // Capturar navigator antes de cualquier await para no usar BuildContext
        // a través de gaps async.
        final navigator = Navigator.of(context);
        // Ejecutar diagnósticos adicionales para ayudar a depurar problemas
        // en dispositivos donde el login no funciona (App Check / Firestore / FCM).
        try {
          await _postLoginDiagnostics(user);
        } catch (_) {}
        navigator.pushReplacementNamed('/');
      } else {
        setState(() {
          _error = 'Credenciales inválidas';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F4C81), Color(0xFF1E88E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Card(
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo / title: try to load asset image, fallback to CA circle
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              'CA',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Caja de Ahorros Para Un Futuro Mejor',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Accede a tu cuenta y gestiona tus ahorros y préstamos',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 18),

                    // Form
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.email),
                        labelText: 'Correo electrónico',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock),
                        labelText: 'Contraseña',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 10),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _loading ? null : _tryLogin,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Iniciar sesión',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Self-registration is disabled; only admins can create users.
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/forgot_password');
                          },
                          child: const Text('¿Olvidaste la contraseña?'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),
                    const Divider(),
                    const SizedBox(height: 6),

                    // Social / quick actions (placeholders)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.fingerprint),
                          onPressed: () async {
                            if (!mounted) return;
                            await showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Acceso biométrico'),
                                content: const Text(
                                  'El acceso biométrico no está configurado o no está disponible en este dispositivo.\n\nPara activarlo, asegúrate de haber registrado una huella/datos biométricos en el sistema y configura la opción en la app.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('Cerrar'),
                                  ),
                                ],
                              ),
                            );
                          },
                          tooltip: 'Acceso biométrico (si está disponible)',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.phone_android),
                          onPressed: () async {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Acceso rápido no configurado'),
                              ),
                            );
                          },
                          tooltip: 'Acceso rápido',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
