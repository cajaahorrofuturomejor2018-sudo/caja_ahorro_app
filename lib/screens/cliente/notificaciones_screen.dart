import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/firestore_service.dart';

class NotificacionesScreen extends StatelessWidget {
  const NotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final fs = FirestoreService();
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('No autenticado')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: fs.streamNotificacionesParaUsuario(uid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No hay notificaciones'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (ctx, index) => const Divider(),
            itemBuilder: (context, i) {
              final n = items[i];
              return ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(n['titulo'] ?? ''),
                subtitle: Text(n['mensaje'] ?? ''),
                trailing: Text(
                  (n['fecha_envio'] as Timestamp?)
                          ?.toDate()
                          .toLocal()
                          .toString() ??
                      '',
                ),
                onTap: () {},
              );
            },
          );
        },
      ),
    );
  }
}
