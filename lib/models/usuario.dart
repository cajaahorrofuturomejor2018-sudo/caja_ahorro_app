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
    // Normalize multiple possible name fields used across environments/exports.
    String resolveName(Map<String, dynamic> d) {
      final candidates = [
        'nombres',
        'nombre',
        'displayName',
        'full_name',
        'nombre_completo',
        'nombreCompleto',
        'name',
      ];
      for (final k in candidates) {
        final v = d[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      // Try to compose from first/last name fields if present
      final first = d['nombre'] as String? ?? '';
      final last = d['apellido'] as String? ?? d['apellidos'] as String? ?? '';
      final combined = '${first.trim()} ${last.trim()}'.trim();
      if (combined.isNotEmpty) return combined;
      return '';
    }

    return Usuario(
      id: doc.id,
      nombres: resolveName(data),
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
