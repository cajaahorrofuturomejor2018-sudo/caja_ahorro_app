import 'package:flutter/material.dart';
import '../services/security_service.dart';

class RoleGuard extends StatelessWidget {
  final Widget child;
  final String requiredRole;

  const RoleGuard({super.key, required this.child, required this.requiredRole});

  @override
  Widget build(BuildContext context) {
    final security = SecurityService();

    return FutureBuilder<bool>(
      future: security.hasPermission(requiredRole),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == false) {
          return const Scaffold(
            body: Center(
              child: Text('Acceso denegado', style: TextStyle(fontSize: 18)),
            ),
          );
        }

        return child;
      },
    );
  }
}
