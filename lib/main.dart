// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// Firebase App Check and path/Platform helpers removed from main as App Check
// is temporarily disabled to ease testing for a controlled group.

import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/cliente/cliente_dashboard.dart';
import 'screens/admin/admin_caja.dart';
import 'screens/admin/admin_add_aporte.dart';
import 'widgets/user_activity_watcher.dart';
import 'core/services/notification_service.dart';

/// Punto de entrada principal de la aplicación.
/// Inicializa Firebase y registra las rutas usadas por la app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // App Check is currently disabled for quick testing/release to a controlled
  // group. Server-side Firestore rules were hardened to limit data exposure.

  // Inicializar Firebase App Check: en release activamos los proveedores de
  // producción (Play Integrity / App Attest) y en debug usamos el debug provider.
  // IMPORTANTE: además de esto debes habilitar el provider correspondiente en
  // Firebase Console y subir cualquier credencial requerida (SHA-256 para Android,
  // registrar el paquete, configurar App Attest en Apple, etc.).
  // App Check desactivado temporalmente por petición del equipo de desarrollo.
  // Si quieres reactivar App Check en el futuro, restaura la lógica de
  // inicialización (activar providers y registrar credenciales en Console).
  // ignore: avoid_print
  print('AppCheck is DISABLED for this build (dev override)');

  // Inicializar notificaciones (si está disponible) — útil para que la app muestre
  // y registre el token FCM en logs. No detenemos el arranque si falla.
  try {
    await NotificationService().initialize();
    // ignore: avoid_print
    print('NotificationService inicializado');
  } catch (e) {
    // ignore: avoid_print
    print('No se pudo inicializar NotificationService: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final navigatorKey = GlobalKey<NavigatorState>();

    return UserActivityWatcher(
      navigatorKey: navigatorKey,
      child: MaterialApp(
        title: 'Caja Ahorro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        initialRoute: '/',
        navigatorKey: navigatorKey,
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/admin': (context) => const AdminDashboard(),
          '/admin/caja': (context) => const AdminCajaScreen(),
          '/admin/add_aporte': (context) => const AdminAddAporteScreen(),
          '/cliente': (context) => const ClienteDashboard(),
        },
      ),
    );
  }
}
