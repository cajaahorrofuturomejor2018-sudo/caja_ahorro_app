import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/deposito.dart';
import '../../models/prestamo.dart';
import '../../models/usuario.dart';

class PDFService {
  PDFService();

  /// Genera un PDF en bytes según los datos provistos.
  Future<Uint8List> generateReportPdf(Map<String, dynamic> data) async {
    final doc = pw.Document();
    // Prefer loading local embedded fonts (assets) to avoid network
    // dependency in tests/CI. If assets are absent, fall back to
    // PdfGoogleFonts (will download from fonts.gstatic.com).
    pw.Font baseFont;
    pw.Font? boldFont;
    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      // Quick sanity-check of TTF/OTF header to avoid passing invalid data
      final bytes = fontData.buffer.asUint8List();
      if (bytes.length < 4 ||
          !((bytes[0] == 0 &&
                  bytes[1] == 1 &&
                  bytes[2] == 0 &&
                  bytes[3] == 0) ||
              (bytes[0] == 0x4F &&
                  bytes[1] == 0x54 &&
                  bytes[2] == 0x54 &&
                  bytes[3] == 0x4F))) {
        throw Exception('Invalid font file');
      }
      baseFont = pw.Font.ttf(fontData.buffer.asByteData());
      try {
        final boldData = await rootBundle.load(
          'assets/fonts/NotoSans-Bold.ttf',
        );
        final bbytes = boldData.buffer.asUint8List();
        if (bbytes.length < 4 ||
            !((bbytes[0] == 0 &&
                    bbytes[1] == 1 &&
                    bbytes[2] == 0 &&
                    bbytes[3] == 0) ||
                (bbytes[0] == 0x4F &&
                    bbytes[1] == 0x54 &&
                    bbytes[2] == 0x54 &&
                    bbytes[3] == 0x4F))) {
          throw Exception('Invalid bold font file');
        }
        boldFont = pw.Font.ttf(boldData.buffer.asByteData());
      } catch (_) {
        boldFont = null;
      }
    } catch (_) {
      // Asset not available; fallback to downloading via PdfGoogleFonts
      baseFont = await PdfGoogleFonts.openSansRegular();
      boldFont = await PdfGoogleFonts.openSansBold();
    }

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Reporte General',
              style: pw.TextStyle(fontSize: 20),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Generado: ${data['generated_at'] ?? DateTime.now().toIso8601String()}',
          ),
          pw.SizedBox(height: 10),
          pw.Text('Resumen', style: pw.TextStyle(fontSize: 16)),
          pw.Bullet(
            text:
                'Total depósitos: \$${(data['total_depositos'] ?? 0).toString()}',
          ),
          pw.Bullet(
            text:
                'Total préstamos: \$${(data['total_prestamos'] ?? 0).toString()}',
          ),
          pw.SizedBox(height: 12),
          pw.Text('Detalle de métricas', style: pw.TextStyle(fontSize: 14)),
          pw.TableHelper.fromTextArray(
            context: context,
            data: <List<String>>[
              ['Clave', 'Valor'],
              ...data.entries.map((e) => [e.key, e.value?.toString() ?? '']),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// Genera y muestra/descarga un reporte para un usuario con listas de
  /// depósitos y préstamos.
  Future<Uint8List> generarReporteUsuario(
    Usuario usuario,
    List<Deposito> depositos,
    List<Prestamo> prestamos,
  ) async {
    // Mostrar solo préstamos vigentes; si no hay, se mantiene la lista original
    final prestamosVigentes = prestamos.where((p) {
      final estado = p.estado.toLowerCase();
      return estado == 'vigente';
    }).toList();
    final prestamosParaReporte = prestamosVigentes.isNotEmpty
        ? prestamosVigentes
        : prestamos;
    final pdf = pw.Document();
    // Usar fuente Unicode para evitar problemas con caracteres acentuados
    // Same font loading logic for the user report PDF.
    pw.Font uBaseFont;
    pw.Font? uBoldFont;
    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      final bytes = fontData.buffer.asUint8List();
      if (bytes.length < 4 ||
          !((bytes[0] == 0 &&
                  bytes[1] == 1 &&
                  bytes[2] == 0 &&
                  bytes[3] == 0) ||
              (bytes[0] == 0x4F &&
                  bytes[1] == 0x54 &&
                  bytes[2] == 0x54 &&
                  bytes[3] == 0x4F))) {
        throw Exception('Invalid font file');
      }
      uBaseFont = pw.Font.ttf(fontData.buffer.asByteData());
      try {
        final boldData = await rootBundle.load(
          'assets/fonts/NotoSans-Bold.ttf',
        );
        final bbytes = boldData.buffer.asUint8List();
        if (bbytes.length < 4 ||
            !((bbytes[0] == 0 &&
                    bbytes[1] == 1 &&
                    bbytes[2] == 0 &&
                    bbytes[3] == 0) ||
                (bbytes[0] == 0x4F &&
                    bbytes[1] == 0x54 &&
                    bbytes[2] == 0x54 &&
                    bbytes[3] == 0x4F))) {
          throw Exception('Invalid bold font file');
        }
        uBoldFont = pw.Font.ttf(boldData.buffer.asByteData());
      } catch (_) {
        uBoldFont = null;
      }
    } catch (_) {
      uBaseFont = await PdfGoogleFonts.openSansRegular();
      uBoldFont = await PdfGoogleFonts.openSansBold();
    }

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: uBaseFont, bold: uBoldFont),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Reporte de Movimientos',
              style: pw.TextStyle(fontSize: 24),
            ),
          ),
          pw.Text('Nombre: ${usuario.nombres}'),
          pw.Text('Correo: ${usuario.correo}'),
          pw.Text('Rol: ${usuario.rol}'),
          pw.Divider(),
          pw.Text('Resumen Financiero', style: pw.TextStyle(fontSize: 18)),
          pw.Text('Total ahorros: \$${usuario.totalAhorros}'),
          pw.Text('Total préstamos: \$${usuario.totalPrestamos}'),
          pw.Text('Total multas: \$${usuario.totalMultas}'),
          pw.SizedBox(height: 20),
          pw.Text('Depósitos', style: pw.TextStyle(fontSize: 18)),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Tipo',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Monto',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Fecha',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              ...depositos.map(
                (d) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(d.tipo),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('\$${d.monto.toStringAsFixed(2)}'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(d.fechaDeposito.toString().split(' ')[0]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Préstamos (solo vigentes)',
            style: pw.TextStyle(fontSize: 18),
          ),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Monto',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Interés',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Plazo',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Estado',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              ...prestamosParaReporte.map(
                (p) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        '\$${p.montoSolicitado.toStringAsFixed(2)}',
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('${p.interes}%'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('${p.plazoMeses} meses'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(p.estado),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Genera reporte anual detallado para admin (depósitos, préstamos, usuarios por año).
  Future<Uint8List> generateAnnualReportPdf(
    Map<String, dynamic> reportData,
  ) async {
    final doc = pw.Document();
    pw.Font baseFont;
    pw.Font? boldFont;
    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      baseFont = pw.Font.ttf(fontData.buffer.asByteData());
      try {
        final boldData = await rootBundle.load(
          'assets/fonts/NotoSans-Bold.ttf',
        );
        boldFont = pw.Font.ttf(boldData.buffer.asByteData());
      } catch (_) {
        boldFont = null;
      }
    } catch (_) {
      baseFont = await PdfGoogleFonts.openSansRegular();
      boldFont = await PdfGoogleFonts.openSansBold();
    }

    final year = reportData['year'] ?? DateTime.now().year;
    final generatedAt =
        reportData['generated_at'] ?? DateTime.now().toIso8601String();
    final usuarios =
        (reportData['usuarios'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Reporte Anual $year',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text('Generado: $generatedAt'),
          pw.SizedBox(height: 20),
          pw.Text(
            'Resumen General',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Bullet(text: 'Total de usuarios: ${reportData['total_usuarios']}'),
          pw.Bullet(
            text: 'Total de depósitos: ${reportData['total_depositos']}',
          ),
          pw.Bullet(
            text:
                'Total ahorros: \$${(reportData['total_ahorros'] as num).toStringAsFixed(2)}',
          ),
          pw.Bullet(
            text:
                'Total pago préstamo: \$${(reportData['total_pago_prestamo'] as num).toStringAsFixed(2)}',
          ),
          pw.Bullet(
            text:
                'Total multas: \$${(reportData['total_multas'] as num).toStringAsFixed(2)}',
          ),
          pw.Bullet(
            text:
                'Total plazos fijos: \$${(reportData['total_plazos'] as num).toStringAsFixed(2)}',
          ),
          pw.Bullet(
            text:
                'Total certificados: \$${(reportData['total_certificados'] as num).toStringAsFixed(2)}',
          ),
          pw.Bullet(
            text:
                'Total ahorro voluntario: \$${(reportData['total_ahorro_voluntario'] as num).toStringAsFixed(2)}',
          ),
          pw.Bullet(
            text:
                'Total préstamos solicitados: ${reportData['total_prestamos_solicitados']}',
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Detalle por Usuario',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Nombres',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Correo',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Total Ahorros',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Total Préstamos',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Total Multas',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              ...usuarios.map(
                (u) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text((u['nombres'] as String?) ?? ''),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text((u['correo'] as String?) ?? ''),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        '\$${(u['total_ahorros'] as num).toStringAsFixed(2)}',
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        '\$${(u['total_prestamos'] as num).toStringAsFixed(2)}',
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        '\$${(u['total_multas'] as num).toStringAsFixed(2)}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  /// Genera reporte global detallado para admin (estado general del sistema).
  Future<Uint8List> generateGlobalReportPdf(
    Map<String, dynamic> reportData,
  ) async {
    final doc = pw.Document();
    pw.Font baseFont;
    pw.Font? boldFont;
    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      baseFont = pw.Font.ttf(fontData.buffer.asByteData());
      try {
        final boldData = await rootBundle.load(
          'assets/fonts/NotoSans-Bold.ttf',
        );
        boldFont = pw.Font.ttf(boldData.buffer.asByteData());
      } catch (_) {
        boldFont = null;
      }
    } catch (_) {
      baseFont = await PdfGoogleFonts.openSansRegular();
      boldFont = await PdfGoogleFonts.openSansBold();
    }

    final generatedAt =
        reportData['generated_at'] ?? DateTime.now().toIso8601String();
    final usuarios =
        (reportData['usuarios'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Reporte Global - Estado General del Sistema',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text('Generado: $generatedAt'),
          pw.SizedBox(height: 20),
          pw.Text(
            'Resumen General',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Bullet(text: 'Total de usuarios: ${reportData['total_usuarios']}'),
          pw.Bullet(
            text:
                'Total de depósitos (validados): ${reportData['total_depositos']}',
          ),
          pw.Bullet(
            text:
                'Total ahorros: \$${(reportData['total_ahorros'] as num).toStringAsFixed(2)}',
          ),
          pw.Bullet(
            text:
                'Total multas: \$${(reportData['total_multas'] as num).toStringAsFixed(2)}',
          ),
          pw.Bullet(
            text:
                'Saldo actual de la caja: \$${(reportData['caja_saldo'] as num).toStringAsFixed(2)}',
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Resumen de Préstamos',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Bullet(
            text: 'Total préstamos (todos): ${reportData['total_prestamos']}',
          ),
          pw.Bullet(
            text: 'Préstamos vigentes: ${reportData['prestamos_vigentes']}',
          ),
          pw.Bullet(
            text: 'Préstamos pagados: ${reportData['prestamos_pagados']}',
          ),
          pw.Bullet(
            text: 'Préstamos rechazados: ${reportData['prestamos_rechazados']}',
          ),
          pw.Bullet(
            text:
                'Total vigentes (capital): \$${(reportData['total_prestamos_vigentes'] as num).toStringAsFixed(2)}',
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Detalle por Usuario',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Nombres',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Correo',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Total Ahorros',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Total Préstamos',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      'Total Multas',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              ...usuarios.map(
                (u) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text((u['nombres'] as String?) ?? ''),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text((u['correo'] as String?) ?? ''),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        '\$${(u['total_ahorros'] as num).toStringAsFixed(2)}',
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        '\$${(u['total_prestamos'] as num).toStringAsFixed(2)}',
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        '\$${(u['total_multas'] as num).toStringAsFixed(2)}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }
}
