import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// 'foundation.dart' no es necesario: los símbolos usados ya vienen de material.dart
import '../cliente/cliente_dashboard.dart';
// Administration removed from mobile: admin portal is available on the web (admin platform).
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));

    debugPrint('SplashScreen: iniciando navegación...');
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('SplashScreen: FirebaseAuth.currentUser = ${user?.uid}');

    if (user == null) {
      debugPrint('SplashScreen: usuario no autenticado -> ir a Login');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      // Intentamos leer el perfil del usuario con reintentos frente a
      // errores transitorios de red/servicio (p. ej. cloud_firestore/unavailable).
      try {
        debugPrint('SplashScreen: usuario autenticado, leyendo perfil...');
        final doc = await _getUserDocWithRetry(user.uid, attempts: 3);

        if (doc.exists) {
          final rol = doc.data()?['rol'];
          debugPrint('SplashScreen: documento usuario existe, rol=$rol');
          if (!mounted) return;
          // Redirect all users (including admin) to ClienteDashboard in the mobile app.
          // Admin users should use the web-based admin dashboard.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ClienteDashboard()),
          );
        } else {
          // Si no existe el documento del usuario, creamos uno mínimo para
          // permitir el acceso a la app (asumimos rol 'cliente' por defecto).
          debugPrint(
            'SplashScreen: documento usuario no existe -> creando documento por defecto',
          );
          try {
            await FirebaseFirestore.instance
                .collection('usuarios')
                .doc(user.uid)
                .set({
                  'id': user.uid,
                  'nombres': user.displayName ?? '',
                  'correo': user.email ?? '',
                  'rol': 'cliente',
                  'estado': 'activo',
                  'fecha_registro': DateTime.now(),
                });
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ClienteDashboard()),
            );
          } catch (createErr) {
            debugPrint(
              'SplashScreen: fallo creando documento por defecto: ${createErr.toString()}',
            );
            // Si falla la creación, volvemos al Login para que el usuario
            // pueda reintentar iniciar sesión o reportar el problema.
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        }
      } catch (e) {
        // Si tras los reintentos sigue fallando, avisamos al usuario y
        // damos la opción de reintentar o volver al login.
        debugPrint(
          'SplashScreen: error leyendo perfil del usuario: ${e.toString()}',
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Error de conexión'),
            content: Text(
              'No se pudo consultar la información del usuario.\n'
              'Error: ${e.toString()}.\n\n'
              '¿Quieres reintentar?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Volver al login
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Reintentar la navegación completa
                  _navigate();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Lee el documento del usuario con reintentos exponenciales.
  Future<DocumentSnapshot<Map<String, dynamic>>> _getUserDocWithRetry(
    String uid, {
    int attempts = 3,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .get();
        return doc;
      } catch (e) {
        // Si es un FirebaseException de servicio no disponible, intentamos
        // primero leer desde la cache local antes de volver a reintentar.
        if (e is FirebaseException && e.code == 'unavailable') {
          try {
            final cached = await FirebaseFirestore.instance
                .collection('usuarios')
                .doc(uid)
                .get(const GetOptions(source: Source.cache));
            if (cached.exists) {
              // Log para depuración y devolvemos el documento en cache.
              debugPrint(
                'Firestore: usando documento desde cache debido a unavailable',
              );
              return cached;
            }
          } catch (cacheErr) {
            // Si leer cache falla, seguimos con la estrategia de reintento.
            debugPrint('Firestore cache read failed: ${cacheErr.toString()}');
          }
        }
        attempt++;
        if (attempt >= attempts) rethrow;
        // Exponencial backoff con jitter simple
        final backoffMs = (500 * (1 << attempt));
        final jitter = (backoffMs * 0.2).toInt();
        final wait = Duration(
          milliseconds: backoffMs + (DateTime.now().microsecond % jitter),
        );
        await Future.delayed(wait);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.savings, size: 80, color: Colors.indigo),
            SizedBox(height: 20),
            Text("Cargando...", style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
