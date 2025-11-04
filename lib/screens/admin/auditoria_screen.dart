import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/middleware/role_guard.dart';

class AuditoriaScreen extends StatelessWidget {
  const AuditoriaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      requiredRole: 'admin',
      child: Scaffold(
        appBar: AppBar(title: const Text('Auditoría del Sistema')),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('auditoria')
              .orderBy('fecha', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final logs = snapshot.data!.docs;
            if (logs.isEmpty) {
              return const Center(child: Text('No hay registros de auditoría'));
            }
            return ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index].data() as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.event_note),
                  title: Text(log['descripcion']),
                  subtitle: Text(
                    "${log['correo']} • ${log['fecha'].toDate().toString().split('.')[0]}",
                  ),
                  trailing: Text(
                    log['tipo'].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
