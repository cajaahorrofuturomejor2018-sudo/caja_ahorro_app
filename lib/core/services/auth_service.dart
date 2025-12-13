import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Registro de usuario
  Future<User?> register({
    required String nombre,
    required String correo,
    required String password,
    required String rol,
    String? telefono,
    String? direccion,
    String? estado,
    String? fotoUrl,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: correo,
      password: password,
    );
    final user = result.user;

    if (user != null) {
      await _db.collection('usuarios').doc(user.uid).set({
        'id': user.uid,
        'nombres': nombre,
        'correo': correo,
        'rol': rol,
        'estado': estado ?? 'activo',
        'telefono': telefono ?? '',
        'direccion': direccion ?? '',
        'foto_url': fotoUrl ?? '',
        'fecha_registro': DateTime.now(),
        'total_ahorros': 0.0,
        'total_prestamos': 0.0,
        'total_multas': 0.0,
        'total_plazos_fijos': 0.0,
        'total_certificados': 0.0,
      });
    }
    return user;
  }

  // Iniciar sesión
  Future<User?> login(String correo, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: correo,
      password: password,
    );
    return result.user;
  }

  // Cerrar sesión
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Obtener usuario actual
  User? get currentUser => _auth.currentUser;
}
