import 'package:cloud_firestore/cloud_firestore.dart';

class Usuario {
  final String id;
  final String nombres;
  final String correo;
  final String rol;
  final String estado;
  final String? telefono;
  final String? direccion;
  final String? fotoUrl;
  final double totalAhorros;
  final double totalPrestamos;
  final double totalMultas;
  final double totalPlazosFijos;
  final double totalCertificados;
  final String? numeroCuenta;

  Usuario({
    required this.id,
    required this.nombres,
    required this.correo,
    required this.rol,
    required this.estado,
    this.telefono,
    this.direccion,
    this.fotoUrl,
    this.numeroCuenta,
    required this.totalAhorros,
    required this.totalPrestamos,
    required this.totalMultas,
    this.totalPlazosFijos = 0.0,
    this.totalCertificados = 0.0,
  });

  factory Usuario.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Usuario(
      id: doc.id,
      nombres: data['nombres'] ?? '',
      correo: data['correo'] ?? '',
      rol: data['rol'] ?? 'cliente',
      estado: data['estado'] ?? 'activo',
      telefono: data['telefono'] ?? '',
      direccion: data['direccion'] ?? '',
      fotoUrl: data['foto_url'] ?? data['fotoUrl'] ?? '',
      totalAhorros: (data['total_ahorros'] ?? 0).toDouble(),
      totalPrestamos: (data['total_prestamos'] ?? 0).toDouble(),
      totalMultas: (data['total_multas'] ?? 0).toDouble(),
      totalPlazosFijos: (data['total_plazos_fijos'] ?? 0).toDouble(),
      totalCertificados: (data['total_certificados'] ?? 0).toDouble(),
      numeroCuenta:
          (data['numero_cuenta'] ?? data['nro_cuenta'] ?? data['cuenta'])
              as String?,
    );
  }
}
