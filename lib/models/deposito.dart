import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class Deposito {
  final String? id; // id del documento en Firestore (opcional)
  final String idUsuario;
  final String tipo;
  final double monto;
  final String? voucherHash;
  final DateTime fechaDeposito;
  final String archivoUrl;
  final bool validado;
  final String? descripcion;
  final List<Map<String, dynamic>>?
  detallePorUsuario; // [{id_usuario, tipo, monto}]
  final String? ocrText;
  final String? detectedAccountRaw;
  final String? detectedAccountDigits;
  final String? detectedName;
  final String? fechaDetectada;
  final double montoSobrante;
  final bool voucherIsPdf;
  final bool ocrVerified;

  Deposito({
    this.id,
    required this.idUsuario,
    required this.tipo,
    required this.monto,
    this.voucherHash,
    required this.fechaDeposito,
    required this.archivoUrl,
    this.validado = false,
    this.descripcion,
    this.detallePorUsuario,
    this.ocrText,
    this.detectedAccountRaw,
    this.detectedAccountDigits,
    this.detectedName,
    this.fechaDetectada,
    this.montoSobrante = 0.0,
    this.voucherIsPdf = false,
    this.ocrVerified = false,
  });

  Map<String, dynamic> toMap() => {
    'id_usuario': idUsuario,
    'tipo': tipo,
    'monto': monto,
    'fecha_deposito': Timestamp.fromDate(fechaDeposito),
    'voucher_hash': voucherHash,
    'ocr_text': ocrText,
    'detected_account_raw': detectedAccountRaw,
    'detected_account_digits': detectedAccountDigits,
    'detected_name': detectedName,
    'fecha_deposito_detectada': fechaDetectada,
    'monto_sobrante': montoSobrante,
    'voucher_is_pdf': voucherIsPdf,
    'ocr_verified': ocrVerified,
    'archivo_url': archivoUrl,
    'validado': validado,
    'descripcion': descripcion,
    'detalle_por_usuario': detallePorUsuario,
    'fecha_registro': FieldValue.serverTimestamp(),
  };

  factory Deposito.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Deposito(
      id: doc.id,
      idUsuario: data['id_usuario'] ?? '',
      tipo: data['tipo'] ?? '',
      monto: (data['monto'] ?? 0).toDouble(),
      voucherHash: data['voucher_hash'] as String?,
      fechaDeposito:
          (data['fecha_deposito'] as Timestamp?)?.toDate() ?? DateTime.now(),
      archivoUrl: data['archivo_url'] ?? '',
      validado: data['validado'] ?? false,
      descripcion: data['descripcion'] as String?,
      ocrText: data['ocr_text'] as String?,
      detectedAccountRaw: data['detected_account_raw'] as String?,
      detectedAccountDigits: data['detected_account_digits'] as String?,
      detectedName: data['detected_name'] as String?,
      fechaDetectada: data['fecha_deposito_detectada'] as String?,
      detallePorUsuario: (() {
        final raw = data['detalle_por_usuario'];
        if (raw is List) {
          final List<Map<String, dynamic>> parsed = [];
          for (final e in raw) {
            if (e is Map) {
              parsed.add(Map<String, dynamic>.from(e));
            } else if (e is String) {
              // Try to decode JSON-encoded map
              try {
                final decoded = jsonDecode(e);
                if (decoded is Map) {
                  parsed.add(Map<String, dynamic>.from(decoded));
                }
              } catch (_) {
                // ignore malformed element
              }
            }
          }
          return parsed;
        }
        return null;
      })(),
      montoSobrante: (data['monto_sobrante'] ?? 0).toDouble(),
      voucherIsPdf: (data['voucher_is_pdf'] ?? false) as bool,
      ocrVerified: (data['ocr_verified'] ?? false) as bool,
    );
  }
}
