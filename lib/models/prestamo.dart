import 'package:cloud_firestore/cloud_firestore.dart';

class Prestamo {
  final String? id; // document id
  final String idUsuario;
  final String? idAdminAprobador;
  final double montoSolicitado;
  final double? montoAprobado;
  final double interes;
  final int plazoMeses;
  final double? cuotaMensual;
  final String? tipo; // tipo de préstamo (ej. consumo, hipotecario, personal)
  final Timestamp? fechaInicio;
  final Timestamp? fechaFin;
  final String estado; // pendiente/aprobado/rechazado/activo/pagado
  final List<dynamic>? historialPagos;
  final String? observaciones;
  final String? certificadoPdfUrl;
  final String? contratoPdfUrl;
  final Timestamp fechaRegistro;

  Prestamo({
    this.id,
    required this.idUsuario,
    this.idAdminAprobador,
    required this.montoSolicitado,
    this.montoAprobado,
    required this.interes,
    required this.plazoMeses,
    this.cuotaMensual,
    this.tipo,
    this.fechaInicio,
    this.fechaFin,
    required this.estado,
    this.historialPagos,
    this.observaciones,
    this.certificadoPdfUrl,
    this.contratoPdfUrl,
    required this.fechaRegistro,
  });

  Map<String, dynamic> toMap() => {
    'id_usuario': idUsuario,
    'id_admin_aprobador': idAdminAprobador,
    'monto_solicitado': montoSolicitado,
    'monto_aprobado': montoAprobado,
    'interes': interes,
    'plazo_meses': plazoMeses,
    'cuota_mensual': cuotaMensual,
    'tipo': tipo,
    'fecha_inicio': fechaInicio,
    'fecha_fin': fechaFin,
    'estado': estado,
    'historial_pagos': historialPagos,
    'observaciones': observaciones,
    'certificado_pdf_url': certificadoPdfUrl,
    'contrato_pdf_url': contratoPdfUrl,
    'fecha_registro': fechaRegistro,
  };

  factory Prestamo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Prestamo(
      id: doc.id,
      idUsuario: data['id_usuario'] ?? '',
      idAdminAprobador: data['id_admin_aprobador'],
      montoSolicitado: (data['monto_solicitado'] ?? 0).toDouble(),
      montoAprobado: data['monto_aprobado'] != null
          ? (data['monto_aprobado'] as num).toDouble()
          : null,
      interes: (data['interes'] ?? 0).toDouble(),
      plazoMeses: (data['plazo_meses'] ?? 0),
      cuotaMensual: data['cuota_mensual'] != null
          ? (data['cuota_mensual'] as num).toDouble()
          : null,
      fechaInicio: data['fecha_inicio'] as Timestamp?,
      fechaFin: data['fecha_fin'] as Timestamp?,
      estado: data['estado'] ?? 'pendiente',
      historialPagos: data['historial_pagos'] as List<dynamic>?,
      observaciones: data['observaciones'] as String?,
      certificadoPdfUrl: data['certificado_pdf_url'] as String?,
      contratoPdfUrl: data['contrato_pdf_url'] as String?,
      tipo: data['tipo'] as String?,
      fechaRegistro: (data['fecha_registro'] as Timestamp?) ?? Timestamp.now(),
    );
  }
}
