import 'package:cloud_firestore/cloud_firestore.dart';

class CalculoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Calcular interés simple: I = P * r * t
  double calcularInteres(double monto, double tasa, int meses) {
    final interes = monto * (tasa / 100) * (meses / 12);
    return double.parse(interes.toStringAsFixed(2));
  }

  // Calcular multa por retraso (2% mensual, ajustable)
  double calcularMulta(double saldo, int diasRetraso) {
    final multa = saldo * 0.02 * (diasRetraso / 30);
    return double.parse(multa.toStringAsFixed(2));
  }

  // Actualizar datos del préstamo con interés calculado
  Future<void> aplicarInteres(
    String idPrestamo,
    double monto,
    double tasa,
    int meses,
  ) async {
    final interes = calcularInteres(monto, tasa, meses);
    await _db.collection('prestamos').doc(idPrestamo).update({
      'interes': tasa,
      'monto_aprobado': monto + interes,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  // Registrar multa al usuario
  Future<void> aplicarMulta(String idUsuario, double multa) async {
    final ref = _db.collection('usuarios').doc(idUsuario);
    await _db.runTransaction((t) async {
      final snap = await t.get(ref);
      final total = (snap['total_multas'] ?? 0).toDouble() + multa;
      t.update(ref, {'total_multas': total});
    });
  }
}
