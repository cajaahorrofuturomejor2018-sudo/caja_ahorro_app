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
          // Mostrar error si el stream falló (p. ej. permisos Firestore / reglas)
          if (snap.hasError) {
            final err = snap.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Error cargando notificaciones:\n${err.toString()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const NotificacionesScreen(),
                        ),
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Mostrar indicador de carga mientras el stream se conecta
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Ya conectado: si no hay datos o lista vacía mostrar mensaje
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No hay notificaciones'));
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (ctx, index) => const Divider(),
            itemBuilder: (context, i) {
              final n = items[i];
              String fechaStr = '';
              try {
                final ts = n['fecha_envio'] as Timestamp?;
                if (ts != null) {
                  fechaStr = ts.toDate().toLocal().toString().split(' ').first;
                }
              } catch (_) {}
              return ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(n['titulo'] ?? ''),
                subtitle: Text(n['mensaje'] ?? ''),
                trailing: Text(fechaStr),
                onTap: () {},
              );
            },
          );
        },
      ),
    );
  }
}
