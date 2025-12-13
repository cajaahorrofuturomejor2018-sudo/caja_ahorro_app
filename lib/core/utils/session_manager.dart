import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/screens/auth/login_screen.dart';

class SessionManager {
  static Timer? _timer;
  static const int _timeout = 60; // 1 minuto de inactividad

  static void startSessionTimer(BuildContext context) {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: _timeout), () {
      FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    });
  }

  static void resetTimer(BuildContext context) {
    startSessionTimer(context);
  }

  static void cancelTimer() {
    _timer?.cancel();
  }
}
