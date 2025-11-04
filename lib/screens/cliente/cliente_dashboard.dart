import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/shared/pdf_preview_screen.dart';
import '../../core/services/firestore_service.dart';
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

class ClienteDashboard extends StatefulWidget {
  const ClienteDashboard({super.key});

  @override
  State<ClienteDashboard> createState() => _ClienteDashboardState();
}

class _ClienteDashboardState extends State<ClienteDashboard> {
  final service = FirestoreService();
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
                      '👤 ${usuario!.nombres}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('Correo: ${usuario!.correo}'),
                    const SizedBox(height: 10),
                    Text('Rol: ${usuario!.rol}'),
                    const SizedBox(height: 16),

                    // Resumen en cards (responsive)
                    // Calculamos los totales dinámicamente a partir de los depósitos
                    // del usuario (solo depósitos válidos). Si hay discrepancia con
                    // los campos almacenados en `usuarios`, los mostramos como fallback.
                    StreamBuilder<List<Deposito>>(
                      stream: service.getDepositos(usuario!.id),
                      builder: (context, snap) {
                        double sumAhorros = 0.0;
                        double sumPlazos = 0.0;
                        double sumPagoPrestamo = 0.0;
                        double sumCertificados = 0.0;
                        if (snap.hasData) {
                          for (final d in snap.data!) {
                            // Contar solo depósitos validados
                            if (!d.validado) continue;
                            switch (d.tipo) {
                              case 'plazo_fijo':
                                sumPlazos += d.monto;
                                break;
                              case 'pago_prestamo':
                                sumPagoPrestamo += d.monto;
                                break;
                              case 'certificado':
                                sumCertificados += d.monto;
                                break;
                              case 'ahorro':
                              default:
                                // 'ahorro' y tipos no explícitos se consideran ahorro por defecto
                                sumAhorros += d.monto;
                                break;
                            }
                          }
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = (constraints.maxWidth - 16) / 4;
                            Widget card(
                              String title,
                              Color? color,
                              double value,
                              double fallback,
                            ) {
                              final display = (value > 0) ? value : fallback;
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
                                  'Total Ahorros',
                                  Colors.green[50],
                                  sumAhorros,
                                  usuario!.totalAhorros,
                                ),
                                card(
                                  'Total Préstamos',
                                  Colors.blue[50],
                                  usuario!.totalPrestamos,
                                  sumPagoPrestamo,
                                ),
                                card(
                                  'Multas',
                                  Colors.orange[50],
                                  usuario!.totalMultas,
                                  usuario!.totalMultas,
                                ),
                                card(
                                  'Total Plazos fijos',
                                  Colors.purple[50],
                                  sumPlazos,
                                  usuario!.totalPlazosFijos,
                                ),
                                // Certificados de aportación
                                card(
                                  'Certificados',
                                  Colors.teal[50],
                                  sumCertificados,
                                  usuario!.totalCertificados,
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
                        double totalOutstanding = 0.0;
                        final List<Map<String, dynamic>> resumen = [];
                        for (final p in prestamos) {
                          final montoAprob =
                              (p.montoAprobado ?? p.montoSolicitado);
                          double totalPagado = 0.0;
                          if (p.historialPagos != null) {
                            for (final hp in p.historialPagos!) {
                              try {
                                final m =
                                    (hp['monto'] ?? hp['monto_pagado'] ?? 0);
                                totalPagado += (m is num)
                                    ? m.toDouble()
                                    : double.parse(m.toString());
                              } catch (_) {}
                            }
                          }
                          var saldo = montoAprob - totalPagado;
                          if (saldo < 0) saldo = 0.0;
                          final mesesRestantes =
                              (p.cuotaMensual != null &&
                                  (p.cuotaMensual ?? 0) > 0)
                              ? (saldo / (p.cuotaMensual ?? 1)).ceil()
                              : p.plazoMeses;
                          totalOutstanding += saldo;
                          resumen.add({
                            'id': p.id,
                            'estado': p.estado,
                            'monto_aprobado': montoAprob,
                            'cuota': p.cuotaMensual ?? 0.0,
                            'plazo_meses': p.plazoMeses,
                            'saldo': saldo,
                            'meses_restantes': mesesRestantes,
                            'fecha_inicio': p.fechaInicio,
                            'fecha_fin': p.fechaFin,
                            'tipo': p.tipo,
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
                                  const Text(
                                    'Resumen de préstamos',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Saldo total pendiente: \$${totalOutstanding.toStringAsFixed(2)}',
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
                                        var subtitleText =
                                            'Aprobado: \$${(r['monto_aprobado'] as double).toStringAsFixed(2)} • Cuota: \$${(r['cuota'] as double).toStringAsFixed(2)} • Plazo: ${r['plazo_meses']} meses';
                                        if (fechaFin.isNotEmpty) {
                                          subtitleText += ' • Fin: $fechaFin';
                                        }
                                        return ListTile(
                                          dense: true,
                                          title: Text(
                                            '${r['tipo'] ?? 'Préstamo'} — Estado: ${r['estado']}',
                                          ),
                                          subtitle: Text(subtitleText),
                                          trailing: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Saldo: \$${(r['saldo'] as double).toStringAsFixed(2)}',
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Meses rem: ${r['meses_restantes']}',
                                              ),
                                            ],
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
