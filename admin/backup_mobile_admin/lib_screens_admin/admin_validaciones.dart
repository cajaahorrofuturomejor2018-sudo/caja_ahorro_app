import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/logger.dart';

class AdminValidaciones extends StatefulWidget {
  const AdminValidaciones({super.key});

  @override
  State<AdminValidaciones> createState() => _AdminValidacionesState();
}

class _AdminValidacionesState extends State<AdminValidaciones> {
  int _index = 0;
  final FirestoreService _service = FirestoreService();
  final Map<String, TextEditingController> _finesCtrls = {};

  @override
  Widget build(BuildContext context) {
    final tabs = [_buildLista('depositos'), _buildLista('prestamos')];

    return Scaffold(
      appBar: AppBar(title: const Text('Validaciones')),
      body: tabs[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'Depósitos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.request_page),
            label: 'Préstamos',
          ),
        ],
      ),
    );
  }

  Widget _buildLista(String coleccion) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(coleccion).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('Sin registros'));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text(
                  coleccion == 'depositos'
                      ? 'Depósito \$${data['monto']}'
                      : 'Préstamo \$${data['monto_solicitado'] ?? 0}',
                ),
                subtitle: Text('Usuario: ${data['id_usuario']}'),
                onTap: () => _showDepositReview(docs[i].id, data),
                trailing: const Icon(Icons.visibility),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    for (final c in _finesCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _showDepositReview(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    // Prepare controllers for each detalle user
    final detalle = data['detalle_por_usuario'];
    List<Map<String, dynamic>> detalleParsed = [];
    if (detalle is List) {
      detalleParsed = List<Map<String, dynamic>>.from(
        detalle.map((e) => e is Map ? Map<String, dynamic>.from(e) : {}),
      );
    } else if (detalle is String) {
      try {
        final dec = jsonDecode(detalle);
        if (dec is List) {
          detalleParsed = List<Map<String, dynamic>>.from(
            dec.map((e) => e is Map ? Map<String, dynamic>.from(e) : {}),
          );
        }
      } catch (_) {}
    }

    // Initialize controllers
    _finesCtrls.clear();
    for (final part in detalleParsed) {
      final uid = (part['id_usuario'] ?? '') as String;
      _finesCtrls[uid] = TextEditingController(text: '0');
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Revisión de depósito'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((data['archivo_url'] ?? '').toString().isNotEmpty) ...[
                  SizedBox(
                    height: 200,
                    child: Image.network(
                      data['archivo_url'],
                      fit: BoxFit.contain,
                      errorBuilder: (ctxErr, err, stack) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text('Monto: \$${data['monto']}'),
                const SizedBox(height: 8),
                if (detalleParsed.isNotEmpty) ...[
                  const Text('Detalle por usuario (ingrese multas si aplica):'),
                  const SizedBox(height: 6),
                  for (final part in detalleParsed) ...[
                    Builder(
                      builder: (bctx) {
                        final uid = (part['id_usuario'] ?? '') as String;
                        final nombre = uid;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Expanded(child: Text(nombre)),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: _finesCtrls[uid],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Multa',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Rechazar: marcar validado=false
                try {
                  await _service.approveDeposito(
                    docId,
                    adminUid,
                    approve: false,
                    observaciones: 'Rechazado por admin',
                  );
                  if (!mounted) return;
                  Navigator.of(context).pop();
                } catch (e) {
                  AppLogger.error('Rechazo depósito error', e, null);
                }
              },
              child: const Text('Rechazar'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Construir mapa de multas
                final Map<String, double> multas = {};
                for (final entry in _finesCtrls.entries) {
                  final txt = entry.value.text.trim();
                  final val = double.tryParse(txt.replaceAll(',', '.')) ?? 0.0;
                  if (val > 0) multas[entry.key] = val;
                }
                try {
                  await _service.approveDeposito(
                    docId,
                    adminUid,
                    approve: true,
                    detalleOverride: detalleParsed.isNotEmpty
                        ? detalleParsed
                        : null,
                    multasPorUsuario: multas,
                  );
                  if (!mounted) return;
                  Navigator.of(context).pop();
                } catch (e) {
                  AppLogger.error('Aprobación depósito error', e, null);
                }
              },
              child: const Text('Aprobar'),
            ),
          ],
        );
      },
    );
  }
}
