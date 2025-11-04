import 'package:flutter_test/flutter_test.dart';
import 'package:caja_ahorro_app/core/services/pdf_service.dart';
import 'package:caja_ahorro_app/models/usuario.dart';
import 'package:caja_ahorro_app/models/deposito.dart';
import 'package:caja_ahorro_app/models/prestamo.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PDFService.generarReporteUsuario devuelve bytes no vacíos', () async {
    final user = Usuario(
      id: 'u_test',
      nombres: 'Test User',
      correo: 'test@example.com',
      rol: 'cliente',
      estado: 'activo',
      totalAhorros: 1500.0,
      totalPrestamos: 900.0,
      totalMultas: 0.0,
    );

    final depositos = [
      Deposito(
        id: 'd1',
        idUsuario: 'u_test',
        tipo: 'Ahorro',
        monto: 500.0,
        fechaDeposito: DateTime.now(),
        archivoUrl: '',
      ),
    ];

    final prestamos = [
      Prestamo(
        id: 'p1',
        idUsuario: 'u_test',
        idAdminAprobador: null,
        montoSolicitado: 1000.0,
        montoAprobado: 900.0,
        interes: 5.0,
        plazoMeses: 12,
        cuotaMensual: 85.0,
        tipo: 'Personal',
        fechaInicio: Timestamp.fromDate(DateTime.now()),
        fechaFin: null,
        estado: 'activo',
        historialPagos: [],
        observaciones: null,
        certificadoPdfUrl: null,
        contratoPdfUrl: null,
        fechaRegistro: Timestamp.fromDate(DateTime.now()),
      ),
    ];

    final pdfService = PDFService();
    final bytes = await pdfService.generarReporteUsuario(
      user,
      depositos,
      prestamos,
    );

    expect(bytes, isNotNull);
    expect(bytes.length, greaterThan(0));
  });
}
