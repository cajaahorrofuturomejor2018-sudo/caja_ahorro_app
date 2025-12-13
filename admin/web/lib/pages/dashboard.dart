import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<dynamic> deposits = [];
  bool loading = true;

  Future<void> load() async {
    setState(() {
      loading = true;
    });
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return; // should redirect to login
    final api = ApiService(token);
    final dep = await api.getDeposits();
    setState(() {
      deposits = dep;
      loading = false;
    });
  }

  Future<void> approve(String id) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return;
    final api = ApiService(token);
    await api.approveDeposit(id, approve: true);
    await load();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: deposits.length,
              itemBuilder: (context, index) {
                final d = deposits[index] as Map<String, dynamic>;
                return ListTile(
                  title: Text(
                      'Deposit ${d['id'] ?? ''} - S/${(d['monto'] ?? d['monto_solicitado'] ?? 0).toString()}'),
                  subtitle: Text('Estado: ${d['estado'] ?? ''}'),
                  trailing: d['estado'] == 'pendiente'
                      ? ElevatedButton(
                          onPressed: () => approve(d['id']),
                          child: const Text('Aprobar'))
                      : null,
                );
              },
            ),
    );
  }
}
