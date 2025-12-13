import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/pdf_service.dart';
import '../shared/pdf_preview_screen.dart';

class AdminReportesScreen extends StatefulWidget {
  const AdminReportesScreen({super.key});

  @override
  State<AdminReportesScreen> createState() => _AdminReportesScreenState();
}

class _AdminReportesScreenState extends State<AdminReportesScreen> {
  final _service = FirestoreService();
  final _pdfService = PDFService();
  bool _loading = false;
  String _reportType = 'anual'; // 'anual' o 'global'
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes Detallados (Admin)')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selector de tipo de reporte
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(label: Text('Anual'), value: 'anual'),
                  ButtonSegment(label: Text('Global'), value: 'global'),
                ],
                selected: {_reportType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => _reportType = newSelection.first);
                },
              ),
              const SizedBox(height: 16),

              // Selector de año (solo para reporte anual)
              if (_reportType == 'anual') ...[
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => setState(() => _selectedYear--),
                      child: const Text('Anio anterior'),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$_selectedYear',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => setState(() => _selectedYear++),
                      child: const Text('Anio siguiente'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Botón para generar reporte
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(
                  _reportType == 'anual'
                      ? 'Generar Reporte Anual $_selectedYear'
                      : 'Generar Reporte Global',
                ),
                onPressed: _loading ? null : _generateReport,
              ),
              const SizedBox(height: 24),

              // Vista previa del resumen
              if (!_loading) _buildReportPreview(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateReport() async {
    setState(() => _loading = true);
    try {
      final navigator = Navigator.of(context);

      if (_reportType == 'anual') {
        final bytes = await _generateAnnualReport(_selectedYear);
        if (!mounted) return;
        navigator.push(
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              bytes: bytes,
              filename: 'reporte_anual_$_selectedYear.pdf',
            ),
          ),
        );
      } else {
        final bytes = await _generateGlobalReport();
        if (!mounted) return;
        navigator.push(
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              bytes: bytes,
              filename: 'reporte_global_${DateTime.now().year}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Uint8List> _generateAnnualReport(int year) async {
    // Obtener todos los usuarios
    final usuarios = await _service.getAllUsuarios();

    // Obtener todos los depósitos y filtrar por año
    final allDepositos = await _service.getAllDepositos();
    final depositosYear = allDepositos.where((d) {
      final depYear = d.fechaDeposito.year;
      return depYear == year && d.validado;
    }).toList();

    // Obtener todos los préstamos y filtrar por año
    final allPrestamos = await _service.getAllPrestamos();
    final prestamosYear = allPrestamos.where((p) {
      final preYear = p.fechaRegistro.toDate().year;
      return preYear == year;
    }).toList();

    // Calcular totales por tipo de depósito
    double totalAhorros = 0;
    double totalPagoPrestamo = 0;
    double totalMultas = 0;
    double totalPlazos = 0;
    double totalCertificados = 0;
    double totalAhorroVoluntario = 0;

    for (final d in depositosYear) {
      switch (d.tipo) {
        case 'ahorro':
          totalAhorros += d.monto;
          break;
        case 'pago_prestamo':
          totalPagoPrestamo += d.monto;
          break;
        case 'multa':
          totalMultas += d.monto;
          break;
        case 'plazo_fijo':
          totalPlazos += d.monto;
          break;
        case 'certificado':
          totalCertificados += d.monto;
          break;
        case 'ahorro_voluntario':
          totalAhorroVoluntario += d.monto;
          break;
      }
    }

    // Datos para el PDF
    final reportData = {
      'type': 'annual',
      'year': year,
      'generated_at': DateTime.now().toIso8601String(),
      'total_usuarios': usuarios.length,
      'total_depositos': depositosYear.length,
      'total_ahorros': totalAhorros,
      'total_pago_prestamo': totalPagoPrestamo,
      'total_multas': totalMultas,
      'total_plazos': totalPlazos,
      'total_certificados': totalCertificados,
      'total_ahorro_voluntario': totalAhorroVoluntario,
      'total_prestamos_solicitados': prestamosYear.length,
      'usuarios': usuarios
          .map(
            (u) => {
              'id': u.id,
              'nombres': u.nombres,
              'correo': u.correo,
              'total_ahorros': u.totalAhorros,
              'total_prestamos': u.totalPrestamos,
              'total_multas': u.totalMultas,
            },
          )
          .toList(),
    };

    return _pdfService.generateAnnualReportPdf(reportData);
  }

  Future<Uint8List> _generateGlobalReport() async {
    // Obtener todos los usuarios
    final usuarios = await _service.getAllUsuarios();

    // Obtener todos los depósitos validados
    final depositos = await _service.getAllDepositos();
    final depositosValidados = depositos.where((d) => d.validado).toList();

    // Obtener todos los préstamos
    final prestamos = await _service.getAllPrestamos();

    // Obtener saldo de caja
    final cajaSaldo = await _service.getCajaSaldo();

    // Calcular totales por tipo
    double totalAhorros = 0;
    double totalPagoPrestamo = 0;
    double totalMultas = 0;
    double totalPlazos = 0;
    double totalCertificados = 0;
    double totalAhorroVoluntario = 0;

    for (final d in depositosValidados) {
      switch (d.tipo) {
        case 'ahorro':
          totalAhorros += d.monto;
          break;
        case 'pago_prestamo':
          totalPagoPrestamo += d.monto;
          break;
        case 'multa':
          totalMultas += d.monto;
          break;
        case 'plazo_fijo':
          totalPlazos += d.monto;
          break;
        case 'certificado':
          totalCertificados += d.monto;
          break;
        case 'ahorro_voluntario':
          totalAhorroVoluntario += d.monto;
          break;
      }
    }

    // Contar préstamos por estado
    int prestamosVigentes = 0;
    int prestamosPagados = 0;
    int prestamosRechazados = 0;
    double totalPrestamosVigentes = 0;

    for (final p in prestamos) {
      final estado = p.estado.toLowerCase();
      if (estado == 'vigente') {
        prestamosVigentes++;
        totalPrestamosVigentes += p.montoSolicitado;
      } else if (estado == 'pagado') {
        prestamosPagados++;
      } else if (estado == 'rechazado') {
        prestamosRechazados++;
      }
    }

    // Datos para el PDF
    final reportData = {
      'type': 'global',
      'generated_at': DateTime.now().toIso8601String(),
      'total_usuarios': usuarios.length,
      'total_depositos': depositosValidados.length,
      'total_ahorros': totalAhorros,
      'total_pago_prestamo': totalPagoPrestamo,
      'total_multas': totalMultas,
      'total_plazos': totalPlazos,
      'total_certificados': totalCertificados,
      'total_ahorro_voluntario': totalAhorroVoluntario,
      'total_prestamos': prestamos.length,
      'prestamos_vigentes': prestamosVigentes,
      'prestamos_pagados': prestamosPagados,
      'prestamos_rechazados': prestamosRechazados,
      'total_prestamos_vigentes': totalPrestamosVigentes,
      'caja_saldo': cajaSaldo,
      'usuarios': usuarios
          .map(
            (u) => {
              'id': u.id,
              'nombres': u.nombres,
              'correo': u.correo,
              'total_ahorros': u.totalAhorros,
              'total_prestamos': u.totalPrestamos,
              'total_multas': u.totalMultas,
            },
          )
          .toList(),
    };

    return _pdfService.generateGlobalReportPdf(reportData);
  }

  Widget _buildReportPreview() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _reportType == 'anual'
          ? _getAnnualReportSummary()
          : _getGlobalReportSummary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _reportType == 'anual'
                      ? 'Resumen Anual $_selectedYear'
                      : 'Resumen Global',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDataRow('Total Usuarios', data['total_usuarios']),
                _buildDataRow('Total Depósitos', data['total_depositos']),
                _buildDataRow(
                  'Total Ahorros',
                  '\$${(data['total_ahorros'] as double).toStringAsFixed(2)}',
                ),
                _buildDataRow(
                  'Total Multas',
                  '\$${(data['total_multas'] as double).toStringAsFixed(2)}',
                ),
                _buildDataRow('Total Préstamos', data['total_prestamos']),
                if (_reportType == 'global')
                  _buildDataRow(
                    'Saldo Caja',
                    '\$${(data['caja_saldo'] as double).toStringAsFixed(2)}',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDataRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getAnnualReportSummary() async {
    final usuarios = await _service.getAllUsuarios();
    final allDepositos = await _service.getAllDepositos();
    final depositosYear = allDepositos
        .where((d) => d.fechaDeposito.year == _selectedYear && d.validado)
        .toList();

    double totalAhorros = 0;
    double totalMultas = 0;

    for (final d in depositosYear) {
      if (d.tipo == 'ahorro') totalAhorros += d.monto;
      if (d.tipo == 'multa') totalMultas += d.monto;
    }

    return {
      'total_usuarios': usuarios.length,
      'total_depositos': depositosYear.length,
      'total_ahorros': totalAhorros,
      'total_multas': totalMultas,
      'total_prestamos': 0,
      'caja_saldo': 0.0,
    };
  }

  Future<Map<String, dynamic>> _getGlobalReportSummary() async {
    final usuarios = await _service.getAllUsuarios();
    final depositos = await _service.getAllDepositos();
    final depositosValidados = depositos.where((d) => d.validado).toList();
    final prestamos = await _service.getAllPrestamos();
    final cajaSaldo = await _service.getCajaSaldo();

    double totalAhorros = 0;
    double totalMultas = 0;

    for (final d in depositosValidados) {
      if (d.tipo == 'ahorro') totalAhorros += d.monto;
      if (d.tipo == 'multa') totalMultas += d.monto;
    }

    return {
      'total_usuarios': usuarios.length,
      'total_depositos': depositosValidados.length,
      'total_ahorros': totalAhorros,
      'total_multas': totalMultas,
      'total_prestamos': prestamos.length,
      'caja_saldo': cajaSaldo,
    };
  }
}
