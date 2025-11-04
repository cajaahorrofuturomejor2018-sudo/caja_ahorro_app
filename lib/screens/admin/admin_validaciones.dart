import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminValidaciones extends StatefulWidget {
  const AdminValidaciones({super.key});

  @override
  State<AdminValidaciones> createState() => _AdminValidacionesState();
}

class _AdminValidacionesState extends State<AdminValidaciones> {
  int _index = 0;

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
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () {
                    FirebaseFirestore.instance
                        .collection(coleccion)
                        .doc(docs[i].id)
                        .update({'validado': true, 'estado': 'aprobado'});
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
