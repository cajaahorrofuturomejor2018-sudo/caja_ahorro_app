import 'package:flutter/material.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/firestore_service.dart';
import '../../models/usuario.dart';
import '../../models/deposito.dart';
import '../../models/prestamo.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReporteClienteScreen extends StatefulWidget {
  const ReporteClienteScreen({super.key});

  @override
  State<ReporteClienteScreen> createState() => _ReporteClienteScreenState();
}

class _ReporteClienteScreenState extends State<ReporteClienteScreen> {
  final firestore = FirestoreService();
  final pdf = PDFService();
  Usuario? usuario;
  List<Deposito> depositos = [];
  List<Prestamo> prestamos = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    usuario = await firestore.getUsuario(uid);
    firestore.getDepositos(uid).listen((d) => setState(() => depositos = d));
    firestore.getPrestamos(uid).listen((p) => setState(() => prestamos = p));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi reporte financiero')),
      body: usuario == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  Text("Total Ahorros: \$${usuario!.totalAhorros}"),
                  Text("Total Préstamos: \$${usuario!.totalPrestamos}"),
                  Text("Multas: \$${usuario!.totalMultas}"),
                  const SizedBox(height: 25),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("Generar reporte PDF"),
                    onPressed: () {
                      pdf.generarReporteUsuario(usuario!, depositos, prestamos);
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
