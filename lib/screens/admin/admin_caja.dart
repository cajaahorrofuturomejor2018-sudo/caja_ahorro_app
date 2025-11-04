import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/firestore_service.dart';
import '../../models/usuario.dart';
import '../../core/services/auth_service.dart';

class AdminCajaScreen extends StatefulWidget {
  const AdminCajaScreen({super.key});

  @override
  State<AdminCajaScreen> createState() => _AdminCajaScreenState();
}

class _AdminCajaScreenState extends State<AdminCajaScreen> {
  final FirestoreService _service = FirestoreService();
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _saldoCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSaldo();
  }

  @override
  void dispose() {
    _saldoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSaldo() async {
    setState(() {
      _loading = true;
    });
    try {
      final saldo = await _service.getCajaSaldo();
      if (mounted) {
        _saldoCtrl.text = saldo.toStringAsFixed(2);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando saldo: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveSaldo() async {
    if (!_formKey.currentState!.validate()) return;
    final confirm = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirmar cambio de caja'),
        content: const Text(
          '¿Deseas actualizar el saldo de la caja con el valor ingresado?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }

    setState(() {
      _loading = true;
    });
    try {
      final value = double.tryParse(_saldoCtrl.text.trim()) ?? 0.0;
      final adminUid = _auth.currentUser?.uid ?? '';
      await _service.setCajaSaldo(value, adminUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saldo de caja actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: ${e.toString()}')),
        );
      }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Caja - Estado')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _saldoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Saldo actual de la caja',
                        prefixText: 'S/ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) =>
                          (v == null || double.tryParse(v) == null)
                          ? 'Ingrese un número válido'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _loading ? null : _saveSaldo,
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Resumen por usuario: mostrar totales contables por cliente
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Resumen por usuario',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: StreamBuilder<List<Usuario>>(
                stream: _service.streamUsuarios(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users = snap.data!;
                  if (users.isEmpty) {
                    return const Center(child: Text('No hay usuarios'));
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final u = users[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: SizedBox(
                          width: 260,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.nombres,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Ahorros: S/ ${u.totalAhorros.toStringAsFixed(2)}',
                                ),
                                Text(
                                  'Plazos fijos: S/ ${u.totalPlazosFijos.toStringAsFixed(2)}',
                                ),
                                Text(
                                  'Certificados: S/ ${u.totalCertificados.toStringAsFixed(2)}',
                                ),
                                Text(
                                  'Préstamos: S/ ${u.totalPrestamos.toStringAsFixed(2)}',
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: () {
                                        _showMovimientosForUser(u.id);
                                      },
                                      child: const Text('Ver movimientos'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () {},
                                      child: const Text('Detalle'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 4),
                    itemCount: users.length,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Movimientos recientes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _service.streamMovimientos(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snap.data!;
                  if (items.isEmpty) {
                    return const Center(child: Text('No hay movimientos'));
                  }
                  return ListView.separated(
                    separatorBuilder: (context, index) => const Divider(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final m = items[index];
                      final monto = (m['monto'] ?? 0).toString();
                      final fecha = m['fecha'] is Timestamp
                          ? (m['fecha'] as Timestamp).toDate().toString()
                          : m['fecha']?.toString() ?? '';
                      // Resolve user names for display
                      return FutureBuilder<List<Usuario>>(
                        future: () async {
                          final uid = (m['id_usuario'] ?? '') as String;
                          if (uid.isEmpty) return <Usuario>[];
                          final users = await _service.getUsuariosByIds([uid]);
                          return users;
                        }(),
                        builder: (context, userSnap) {
                          String nombre = (m['id_usuario'] ?? '') as String;
                          if (userSnap.hasData && userSnap.data!.isNotEmpty) {
                            nombre = userSnap.data!.first.nombres;
                          }
                          return ListTile(
                            title: Text('${m['tipo'] ?? ''} - S/ $monto'),
                            subtitle: Text(
                              '${m['descripcion'] ?? ''}\nUsuario: $nombre',
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              fecha,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMovimientosForUser(String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, controller) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.streamMovimientosForUser(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('No hay movimientos para este usuario'),
                    ),
                  );
                }
                return ListView.separated(
                  controller: controller,
                  separatorBuilder: (context, index) => const Divider(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final m = items[index];
                    final monto = (m['monto'] ?? 0).toString();
                    final fecha = m['fecha'] is Timestamp
                        ? (m['fecha'] as Timestamp).toDate().toString()
                        : m['fecha']?.toString() ?? '';
                    return ListTile(
                      title: Text('${m['tipo'] ?? ''} - S/ $monto'),
                      subtitle: Text('${m['descripcion'] ?? ''}'),
                      trailing: Text(
                        fecha,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
