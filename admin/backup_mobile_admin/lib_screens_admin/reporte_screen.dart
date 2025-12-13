import 'package:flutter/material.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/firestore_service.dart';
import '../../models/usuario.dart';
import '../../models/deposito.dart';
import '../../models/prestamo.dart';

class ReporteScreen extends StatelessWidget {
  final Usuario usuario;
  const ReporteScreen({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final pdf = PDFService();

    return Scaffold(
      appBar: AppBar(title: Text('Reporte de ${usuario.nombres}')),
      body: StreamBuilder<List<Deposito>>(
        stream: firestore.getDepositos(usuario.id),
        builder: (context, depSnap) {
          return StreamBuilder<List<Prestamo>>(
            stream: firestore.getPrestamos(usuario.id),
            builder: (context, preSnap) {
              if (!depSnap.hasData || !preSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Generar PDF de usuario"),
                  onPressed: () {
                    pdf.generarReporteUsuario(
                      usuario,
                      depSnap.data!,
                      preSnap.data!,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
