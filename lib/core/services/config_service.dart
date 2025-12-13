import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Obtener configuración actual
  Future<Map<String, dynamic>?> getConfig() async {
    final doc = await _db
        .collection('configuracion_global')
        .doc('parametros')
        .get();
    return doc.exists ? doc.data() : null;
  }

  // Actualizar configuración
  Future<void> updateConfig(Map<String, dynamic> data) async {
    await _db
        .collection('configuracion_global')
        .doc('parametros')
        .set(data, SetOptions(merge: true));
  }

  // Inicializar configuración por defecto (si no existe)
  Future<void> initConfig() async {
    final docRef = _db.collection('configuracion_global').doc('parametros');
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'tasa_interes_anual': 10.0,
        'porcentaje_multa': 2.0,
        'limite_prestamo': 5000.0,
        'min_ahorro': 10.0,
        'plazos_fijos': [3, 6, 12],
        'ultima_actualizacion': DateTime.now(),
      });
    }
  }
}
