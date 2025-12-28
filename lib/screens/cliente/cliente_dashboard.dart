import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/shared/pdf_preview_screen.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/penalty_check_service.dart';
import '../../core/services/pdf_service.dart';
import '../../models/usuario.dart';
import '../../models/deposito.dart';
import '../../models/prestamo.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'deposito_form_fixed.dart';
import 'prestamo_form.dart';
import 'mis_prestamos.dart';
import 'notificaciones_screen.dart';
import 'editar_perfil.dart';
import 'multas_deposito_form.dart';

class ClienteDashboard extends StatefulWidget {
  const ClienteDashboard({super.key});

  @override
  State<ClienteDashboard> createState() => _ClienteDashboardState();
}

class _ClienteDashboardState extends State<ClienteDashboard> {
  final service = FirestoreService();
  final penaltyCheckService = PenaltyCheckService();
  Usuario? usuario;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        // Verificar y aplicar multas automáticamente ANTES de cargar datos
        await penaltyCheckService.checkAndApplyPenalties(uid);

        if (!mounted) return;

        // Ahora cargar datos actualizados del usuario
        final data = await service.getUsuario(uid);
        if (!mounted) return;
        setState(() {
          usuario = data;
          _errorMessage = null;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          usuario = null;
          _errorMessage = 'Error cargando datos: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar reporte',
            // ignore: use_build_context_synchronously
            // ignore: use_build_context_synchronously
            onPressed: () async {
              final pdfService = PDFService();
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;
              try {
                final usuarioData = await service.getUsuario(uid);
                if (!mounted) return;
                if (usuarioData == null) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Usuario no encontrado')),
                  );
                  return;
                }
                final depositos = await service.getDepositosOnce(uid);
                final prestamos = await service.getPrestamosOnce(uid);
                final bytes = await pdfService.generarReporteUsuario(
                  usuarioData,
                  depositos,
                  prestamos,
                );
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PdfPreviewScreen(
                      bytes: bytes,
                      filename:
                          'reporte_${uid}_${DateTime.now().millisecondsSinceEpoch}.pdf',
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error generando reporte: ${e.toString()}'),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Salir',
            // ignore: use_build_context_synchronously
            // ignore: use_build_context_synchronously
            onPressed: () async {
              if (!mounted) return;
              final navigator = Navigator.of(context);
              final shouldExit = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Salir'),
                  content: const Text('¿Deseas cerrar sesión? ¡Hasta pronto!'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Salir'),
                    ),
                  ],
                ),
              );

              if (shouldExit != true) return;

              try {
                await FirebaseAuth.instance.signOut();
              } catch (_) {}

              if (!mounted) return;
              navigator.pushNamedAndRemoveUntil('/login', (r) => false);
            },
          ),
          IconButton(
            icon: const Icon(Icons.request_page),
            tooltip: 'Solicitar préstamo',
            // ignore: use_build_context_synchronously
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PrestamoForm()));
              _loadUser();
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Mis préstamos',
            // ignore: use_build_context_synchronously
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MisPrestamosScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Notificaciones',
            // ignore: use_build_context_synchronously
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
              );
            },
          ),
        ],
      ),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => _loadUser(),
                          child: const Text('Reintentar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            try {
                              await FirebaseAuth.instance.signOut();
                            } catch (_) {}
                            if (!mounted) return;
                            navigator.pushNamedAndRemoveUntil(
                              '/login',
                              (r) => false,
                            );
                          },
                          child: const Text('Salir'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : usuario == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: ListView(
                  children: [
                    Text(
                      '👤 ${usuario!.nombres.isNotEmpty ? usuario!.nombres : usuario!.id}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Banner de alerta de multas (visible después del día 10 si hay multas)
                    if (DateTime.now().day > 10 &&
                        (usuario?.totalMultas ?? 0) > 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          border: Border.all(color: Colors.red, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red,
                                  size: 28,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '⚠️ MULTAS PENDIENTES',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tienes multas por pagar: \$${usuario!.totalMultas.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No podrás realizar depósitos de ahorro mensual ni pagos de préstamo hasta que pagues tus multas.',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const MultasDepositoForm(),
                                    ),
                                  );
                                  _loadUser();
                                },
                                icon: const Icon(Icons.payment),
                                label: const Text('PAGAR MULTAS AHORA'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text('Correo: ${usuario!.correo}'),
                    const SizedBox(height: 10),
                    Text('Rol: ${usuario!.rol}'),
                    const SizedBox(height: 16),

                    // Resumen en cards (responsive)
                    // Calculamos los totales dinámicamente a partir de TODOS los depósitos
                    // validados en el sistema pero filtrando solo los montos que afectan
                    // al usuario actual. Si un depósito contiene `detalle_por_usuario`,
                    // solo se suman los montos del detalle que correspondan al usuario.
                    // Si no hay detalle, y el depósito fue creado para este usuario
                    // (id_usuario == usuario.id), se toma el monto completo.
                    // Resumen en cards - Mostrar TODOS los tipos de depósito
                    StreamBuilder<List<Deposito>>(
                      stream: service.streamAllDepositos(),
                      builder: (context, snap) {
                        double sumAhorroMensual = 0.0;
                        double sumAhorroVoluntario = 0.0;
                        double sumPlazos = 0.0;
                        double sumPagoPrestamo = 0.0;
                        double sumCertificados = 0.0;

                        if (snap.hasData) {
                          for (final d in snap.data!) {
                            // Contar solo depósitos validados
                            if (!d.validado) continue;
                            // Si el depósito tiene detalle_por_usuario, sumar solo las partes
                            // que correspondan al usuario actual.
                            if (d.detallePorUsuario != null &&
                                d.detallePorUsuario!.isNotEmpty) {
                              for (final part in d.detallePorUsuario!) {
                                try {
                                  final pid =
                                      (part['id_usuario'] ?? '') as String;
                                  if (pid != usuario!.id) continue;
                                  final pmonto = (part['monto'] ?? 0)
                                      .toDouble();
                                  final ptipo =
                                      (part['tipo'] as String?) ?? d.tipo;
                                  switch (ptipo) {
                                    case 'ahorro':
                                      sumAhorroMensual += pmonto;
                                      break;
                                    case 'ahorro_voluntario':
                                      sumAhorroVoluntario += pmonto;
                                      break;
                                    case 'plazo_fijo':
                                      sumPlazos += pmonto;
                                      break;
                                    case 'pago_prestamo':
                                      sumPagoPrestamo += pmonto;
                                      break;
                                    case 'certificado':
                                      sumCertificados += pmonto;
                                      break;
                                  }
                                } catch (_) {}
                              }
                            } else {
                              // No hay detalle: si el depósito fue registrado para este usuario
                              if (d.idUsuario == usuario!.id) {
                                switch (d.tipo) {
                                  case 'ahorro':
                                    sumAhorroMensual += d.monto;
                                    break;
                                  case 'ahorro_voluntario':
                                    sumAhorroVoluntario += d.monto;
                                    break;
                                  case 'plazo_fijo':
                                    sumPlazos += d.monto;
                                    break;
                                  case 'pago_prestamo':
                                    sumPagoPrestamo += d.monto;
                                    break;
                                  case 'certificado':
                                    sumCertificados += d.monto;
                                    break;
                                }
                              }
                            }
                          }
                        }

                        // Verificar si mostrar tarjeta de multas (después del día 10 a las 23:59)
                        final ahora = DateTime.now();
                        final bool mostrarMultas =
                            ahora.day > 10 && (usuario?.totalMultas ?? 0) > 0;

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = (constraints.maxWidth - 16) / 3;
                            Widget card(
                              String title,
                              Color? color,
                              double value,
                              double fallback, {
                              bool ocultarSiCero = false,
                            }) {
                              // CRITICAL FIX: Always use fallback (user's total from Firestore)
                              // The 'value' parameter (sum from deposits stream) is unreliable
                              // because it only includes approved deposits in current session
                              final display = fallback;
                              if (ocultarSiCero && display == 0) {
                                return const SizedBox.shrink();
                              }
                              return SizedBox(
                                width: cardWidth < 200
                                    ? constraints.maxWidth
                                    : cardWidth,
                                child: Card(
                                  color: color,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '\$${display.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                card(
                                  'Ahorro Mensual',
                                  Colors.green[50],
                                  sumAhorroMensual,
                                  usuario!.totalAhorros,
                                ),
                                card(
                                  'Pago Préstamos',
                                  Colors.blue[50],
                                  sumPagoPrestamo,
                                  usuario!.totalPrestamos,
                                ),
                                card(
                                  'Plazos Fijos',
                                  Colors.purple[50],
                                  sumPlazos,
                                  usuario!.totalPlazosFijos,
                                ),
                                card(
                                  'Certificados',
                                  Colors.teal[50],
                                  sumCertificados,
                                  usuario!.totalCertificados,
                                ),
                                card(
                                  'Ahorro Voluntario',
                                  Colors.cyan[50],
                                  sumAhorroVoluntario,
                                  0.0,
                                ),
                                // Mostrar tarjeta de Multas solo si es después del día 10
                                // y si el usuario tiene multas pendientes
                                if (mostrarMultas)
                                  GestureDetector(
                                    onTap: () async {
                                      // Navegar al formulario de multas
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const MultasDepositoForm(),
                                        ),
                                      );
                                      _loadUser();
                                    },
                                    child: Card(
                                      color: Colors.red[50],
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: const [
                                                Icon(
                                                  Icons.warning,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Multas Pendientes',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '\$${usuario!.totalMultas.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Toca para pagar',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    // Próximo pago y resumen de préstamos: buscar préstamos del usuario
                    FutureBuilder<List<Prestamo>>(
                      future: service.getPrestamosOnce(usuario!.id),
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox.shrink();
                        final prestamos = snap.data!;

                        // Próximo pago: buscar el primer préstamo activo
                        Prestamo? activo;
                        for (final p in prestamos) {
                          if (p.estado == 'activo') {
                            activo = p;
                            break;
                          }
                        }

                        // Resumen: calcular saldo pendiente por préstamo y total
                        // IMPORTANTE: Mostrar solo el CAPITAL REAL sin intereses
                        // Ejemplo: Usuario sacó $100, paga $12/mes ($10 capital + $2 interés caja)
                        // El saldo mostrado es solo el capital: $100 - pagos de capital
                        double totalOutstanding = 0.0;
                        final List<Map<String, dynamic>> resumen = [];
                        for (final p in prestamos) {
                          // Monto aprobado = capital real prestado (SIN intereses)
                          final montoCapital =
                              ((p.montoAprobado ?? p.montoSolicitado) as num)
                                  .toDouble();

                          // Calcular cuánto capital ha pagado el usuario
                          // De cada pago mensual, una parte es capital, otra es interés para la caja
                          double capitalPagado = 0.0;
                          if (p.historialPagos != null) {
                            for (final hp in p.historialPagos!) {
                              try {
                                final montoPago =
                                    (hp['monto'] ?? hp['monto_pagado'] ?? 0);
                                final mPago = (montoPago is num)
                                    ? montoPago.toDouble()
                                    : double.parse(montoPago.toString());

                                // Calcular qué parte del pago es capital
                                // Si el préstamo tiene cuotaMensual e interes, calcular proporción
                                final cuota = (p.cuotaMensual ?? 0).toDouble();
                                final tasaInteres = p.interes.toDouble();

                                if (cuota > 0 && tasaInteres > 0) {
                                  // Calcular interés mensual: (capital restante * tasa / 100 / 12)
                                  // Simplificación: usar proporción fija capital/interés
                                  // Interés total = capital * tasa / 100
                                  // En cada cuota: parte fija va a capital
                                  final interesTotalPrestamo =
                                      montoCapital * tasaInteres / 100.0;
                                  final totalAPagar =
                                      montoCapital + interesTotalPrestamo;
                                  final proporcionCapital =
                                      montoCapital / totalAPagar;
                                  capitalPagado += mPago * proporcionCapital;
                                } else {
                                  // Sin interés, todo el pago es capital
                                  capitalPagado += mPago;
                                }
                              } catch (_) {}
                            }
                          }

                          // Saldo = capital prestado - capital pagado
                          var saldoCapital = montoCapital - capitalPagado;
                          if (saldoCapital < 0) saldoCapital = 0.0;

                          // Calcular cuota mensual SOLO de capital (para el usuario)
                          final cuotaMensualTotal = (p.cuotaMensual ?? 0)
                              .toDouble();
                          final tasaInteres = p.interes.toDouble();
                          double cuotaCapital = cuotaMensualTotal;

                          if (cuotaMensualTotal > 0 && tasaInteres > 0) {
                            final interesTotalPrestamo =
                                montoCapital * tasaInteres / 100.0;
                            final totalAPagar =
                                montoCapital + interesTotalPrestamo;
                            final proporcionCapital =
                                montoCapital / totalAPagar;
                            cuotaCapital =
                                cuotaMensualTotal * proporcionCapital;
                          }

                          final mesesRestantes = (cuotaCapital > 0)
                              ? (saldoCapital / cuotaCapital).ceil()
                              : p.plazoMeses;
                          totalOutstanding += saldoCapital;
                          resumen.add({
                            'id': p.id,
                            'estado': p.estado,
                            'monto_aprobado': montoCapital, // Capital real
                            'cuota': cuotaCapital, // Solo porción de capital
                            'cuota_total':
                                cuotaMensualTotal, // Cuota completa (capital + interés)
                            'plazo_meses': p.plazoMeses,
                            'saldo': saldoCapital, // Solo capital pendiente
                            'meses_restantes': mesesRestantes,
                            'fecha_inicio': p.fechaInicio,
                            'fecha_fin': p.fechaFin,
                            'tipo': p.tipo,
                            'interes': tasaInteres,
                          });
                        }

                        Widget buildProximoPagoCard() {
                          if (activo == null) return const SizedBox.shrink();
                          final cuota = activo.cuotaMensual ?? 0.0;
                          String fechaFin = '';
                          try {
                            if (activo.fechaFin != null) {
                              fechaFin = (activo.fechaFin as Timestamp)
                                  .toDate()
                                  .toLocal()
                                  .toString()
                                  .split(' ')
                                  .first;
                            }
                          } catch (_) {}
                          return Card(
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Próximo pago',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cuota mensual: \$${cuota.toStringAsFixed(2)}',
                                  ),
                                  if (fechaFin.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text('Fecha fin del plan: $fechaFin'),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }

                        Widget buildPrestamosResumenCard() {
                          return Card(
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Text(
                                        'Resumen de préstamos',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Tooltip(
                                        message: 'Los montos mostrados son: ',
                                        child: Icon(
                                          Icons.info_outline,
                                          size: 18,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Saldos mostrados:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Deuda total de capital: \$${totalOutstanding.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (resumen.isEmpty)
                                    const Text('No hay préstamos registrados')
                                  else
                                    Column(
                                      children: resumen.map((r) {
                                        String fechaFin = '';
                                        try {
                                          if (r['fecha_fin'] != null) {
                                            fechaFin =
                                                (r['fecha_fin'] as Timestamp)
                                                    .toDate()
                                                    .toLocal()
                                                    .toString()
                                                    .split(' ')
                                                    .first;
                                          }
                                        } catch (_) {}
                                        final montoCapital =
                                            (r['monto_aprobado'] as num?)
                                                ?.toDouble() ??
                                            0.0;
                                        final cuotaCapital =
                                            (r['cuota'] as num?)?.toDouble() ??
                                            0.0;
                                        final tasaInteres =
                                            (r['interes'] as num?)
                                                ?.toDouble() ??
                                            0.0;

                                        // Información del préstamo
                                        var subtitleText =
                                            'Capital prestado: \$${montoCapital.toStringAsFixed(2)} • Plazo: ${r['plazo_meses']} meses';
                                        if (tasaInteres > 0) {
                                          subtitleText +=
                                              ' • Interés caja: ${tasaInteres.toStringAsFixed(1)}%';
                                        }
                                        if (fechaFin.isNotEmpty) {
                                          subtitleText += ' • Vence: $fechaFin';
                                        }

                                        final saldoCapital =
                                            ((r['saldo'] as num?)?.toDouble() ??
                                            0.0);

                                        return Card(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          color: Colors.grey[50],
                                          child: ListTile(
                                            isThreeLine: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                            title: Text(
                                              '${r['tipo'] ?? 'Préstamo'} — ${r['estado']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            subtitle: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4),
                                                Text(
                                                  subtitleText,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Pago mensual capital: \$${cuotaCapital.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            trailing: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                Text(
                                                  'Saldo',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                Text(
                                                  '\$${saldoCapital.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                                Text(
                                                  '${r['meses_restantes']} meses',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildProximoPagoCard(),
                            const SizedBox(height: 8),
                            buildPrestamosResumenCard(),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    // Acciones rápidas
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.request_page),
                          label: const Text('Solicitar préstamo'),
                          // ignore: use_build_context_synchronously
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PrestamoForm(),
                              ),
                            );
                            _loadUser();
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.list_alt),
                          label: const Text('Mis préstamos'),
                          // ignore: use_build_context_synchronously
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MisPrestamosScreen(),
                              ),
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Registrar depósito'),
                          // ignore: use_build_context_synchronously
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DepositoForm(),
                              ),
                            );
                            _loadUser();
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Exportar reporte'),
                          onPressed: () async {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid == null) return;
                            try {
                              final usuarioData = await service.getUsuario(uid);
                              if (!mounted) return;
                              if (usuarioData == null) {
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Usuario no encontrado'),
                                  ),
                                );
                                return;
                              }
                              final depositos = await service.getDepositosOnce(
                                uid,
                              );
                              final prestamos = await service.getPrestamosOnce(
                                uid,
                              );
                              final bytes = await PDFService()
                                  .generarReporteUsuario(
                                    usuarioData,
                                    depositos,
                                    prestamos,
                                  );
                              if (!mounted) return;
                              // ignore: use_build_context_synchronously
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PdfPreviewScreen(
                                    bytes: bytes,
                                    filename: 'reporte_$uid.pdf',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                ),
                              );
                            }
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Editar perfil'),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EditarPerfilScreen(),
                              ),
                            );
                            _loadUser();
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.notifications),
                          label: const Text('Notificaciones'),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NotificacionesScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const Divider(height: 30),
                    const Text(
                      '📄 Depósitos recientes:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                      // reservar parte de la pantalla para la lista de depósitos
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: StreamBuilder<List<Deposito>>(
                        stream: service.getDepositos(usuario!.id),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            final err = snapshot.error;
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Error cargando depósitos:\n\n${err.toString()}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () => _loadUser(),
                                      child: const Text('Reintentar'),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton(
                                      onPressed: () {
                                        showDialog<void>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Por qué ocurre'),
                                            content: SingleChildScrollView(
                                              child: ListBody(
                                                children: const <Widget>[
                                                  Text(
                                                    'Este error suele ocurrir cuando Firebase App Check está activo y el servidor no acepta la atestación del cliente.',
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    'Solución rápida: temporalmente desactivar enforcement en Firebase Console (App Check → Firestore → Monitor/Off), luego ejecutar la app para obtener el debug token y registrarlo en App Check. Después volver a activar enforcement.',
                                                  ),
                                                ],
                                              ),
                                            ),
                                            actions: <Widget>[
                                              TextButton(
                                                child: const Text('Cerrar'),
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        '¿Por qué y cómo arreglarlo?',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final data = snapshot.data!;
                          if (data.isEmpty) {
                            return const Center(
                              child: Text('No hay depósitos registrados'),
                            );
                          }
                          return ListView.builder(
                            itemCount: data.length,
                            itemBuilder: (context, index) {
                              final dep = data[index];
                              return ListTile(
                                leading: const Icon(Icons.receipt_long),
                                title: Text('${dep.tipo} - \$${dep.monto}'),
                                subtitle: Text(
                                  dep.fechaDeposito.toLocal().toString(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ), // Column
              ), // Padding
            ), // SafeArea
      floatingActionButton: FloatingActionButton(
        tooltip: 'Registrar depósito',
        child: const Icon(Icons.add),
        // ignore: use_build_context_synchronously
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const DepositoForm()));
          _loadUser();
        },
      ),
    );
  }
}
