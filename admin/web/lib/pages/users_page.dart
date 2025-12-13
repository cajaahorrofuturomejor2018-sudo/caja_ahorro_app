import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({Key? key}) : super(key: key);

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<dynamic> users = [];
  bool loading = true;

  Future<void> load() async {
    setState(() {
      loading = true;
    });
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return;
    final api = ApiService(token);
    final list = await api.getUsers();
    setState(() {
      users = list;
      loading = false;
    });
  }

  Future<void> setRole(String id, String role) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final api = ApiService(token);
    await api.post(Uri.parse(''));
    await api.setRoleForUser(id, role);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final u = users[index] as Map<String, dynamic>;
                return ListTile(
                  title: Text(u['nombres'] ?? u['id'] ?? ''),
                  subtitle: Text(
                      'ID: ${u['id'] ?? ''} - rol: ${u['rol'] ?? ''} - estado: ${u['estado'] ?? ''}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      try {
                        final token = await FirebaseAuth.instance.currentUser
                            ?.getIdToken();
                        final api = ApiService(token);
                        if (v == 'marcar_admin') {
                          await api.setUserRole(u['id'], 'admin');
                        } else if (v == 'marcar_user') {
                          await api.setUserRole(u['id'], 'user');
                        } else if (v == 'activar') {
                          await api.setUserEstado(u['id'], 'activo');
                        } else if (v == 'desactivar') {
                          await api.setUserEstado(u['id'], 'inactivo');
                        }
                        await load();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')));
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                          value: 'marcar_admin', child: Text('Marcar admin')),
                      const PopupMenuItem(
                          value: 'marcar_user', child: Text('Marcar usuario')),
                      const PopupMenuItem(
                          value: 'activar', child: Text('Activar')),
                      const PopupMenuItem(
                          value: 'desactivar', child: Text('Desactivar')),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
