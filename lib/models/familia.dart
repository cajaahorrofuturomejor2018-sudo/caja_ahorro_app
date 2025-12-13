import 'package:cloud_firestore/cloud_firestore.dart';

class Familia {
  final String id;
  final String nombreGrupo;
  final List<Map<String, dynamic>> miembros; // {id_usuario, rol_familiar}
  final double totalGrupo;
  final DateTime fechaCreacion;
  final String creadoPor;

  Familia({
    required this.id,
    required this.nombreGrupo,
    required this.miembros,
    required this.totalGrupo,
    required this.fechaCreacion,
    required this.creadoPor,
  });

  factory Familia.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Familia(
      id: doc.id,
      nombreGrupo: data['nombre_grupo'] ?? '',
      miembros:
          (data['miembros'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      totalGrupo: (data['total_grupo'] ?? 0).toDouble(),
      fechaCreacion:
          (data['fecha_creacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      creadoPor: data['creado_por'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'nombre_grupo': nombreGrupo,
    'miembros': miembros,
    'total_grupo': totalGrupo,
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
    'creado_por': creadoPor,
  };
}
