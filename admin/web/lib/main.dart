import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/dashboard.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: FirebaseOptions(
    apiKey: firebaseConfig['apiKey']!,
    authDomain: firebaseConfig['authDomain'],
    projectId: firebaseConfig['projectId']!,
    storageBucket: firebaseConfig['storageBucket'],
    messagingSenderId: firebaseConfig['messagingSenderId'],
    appId: firebaseConfig['appId']!,
  ));
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin - Caja Ahorro',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
      },
    );
  }
}
