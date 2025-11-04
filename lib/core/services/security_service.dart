import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SecurityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Registrar acción en auditoría
  Future<void> logAction(String descripcion, {String tipo = 'general'}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('auditoria').add({
      'uid': user.uid,
      'correo': user.email,
      'tipo': tipo,
      'descripcion': descripcion,
      'fecha': DateTime.now(),
    });
  }

  // Obtener rol actual del usuario
  Future<String?> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db.collection('usuarios').doc(user.uid).get();
    if (doc.exists) {
      return doc['rol'];
    }
    return null;
  }

  // Verificar permiso
  Future<bool> hasPermission(String rolRequerido) async {
    final rol = await getUserRole();
    return rol == rolRequerido;
  }
}
