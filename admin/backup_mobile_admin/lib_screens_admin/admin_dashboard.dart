// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

import '../../core/services/firestore_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/ml_service.dart';
import '../../core/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/usuario.dart';
import '../../models/deposito.dart';
import '../../screens/shared/pdf_preview_screen.dart';
import 'admin_add_user.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final FirestoreService _service = FirestoreService();
  final MlService _ml = MlService();
  // Cache of usuarios to avoid per-item lookups
  final Map<String, Usuario> _userMap = {};
  StreamSubscription<List<Usuario>>? _usuariosSub;
  late Future<Map<String, dynamic>?> _configFuture;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _configFuture = _service.getConfiguracion();
    // mantener un cache en memoria de usuarios para mostrar nombres en UI
    _usuariosSub = _service.streamUsuarios().listen(
      (list) {
        AppLogger.info('Usuarios stream received', {'count': list.length});
        setState(() {
          _userMap
            ..clear()
            ..addEntries(list.map((u) => MapEntry(u.id, u)));
        });
      },
      onError: (e, st) {
        AppLogger.error('Usuarios stream error', e, st);
        // ignore errors here; individual stream builders already surface errors
      },
    );
    // rebuild when tab changes so FAB visibility updates
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _usuariosSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del Administrador'),
        actions: [
          IconButton(
            tooltip: 'Generar reporte general',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generateGeneralReport,
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Usuarios', icon: Icon(Icons.people)),
            Tab(text: 'Depósitos', icon: Icon(Icons.receipt_long)),
            Tab(text: 'Préstamos', icon: Icon(Icons.request_page)),
            Tab(text: 'Familias', icon: Icon(Icons.group)),
            Tab(text: 'Reportes', icon: Icon(Icons.bar_chart)),
            Tab(text: 'Configuración', icon: Icon(Icons.settings)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FutureBuilder<double>(
              future: _service.getCajaSaldo(),
              builder: (context, snapSaldo) {
                return Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Saldo de caja',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              snapSaldo.hasData
                                  ? 'S/ ${snapSaldo.data!.toStringAsFixed(2)}'
                                  : 'Cargando...',
                            ),
                          ],
                        ),
                        FutureBuilder<Map<String, double>>(
                          future: _service.getAggregateTotals(),
                          builder: (context, snapTotals) {
                            if (!snapTotals.hasData) {
                              return const SizedBox.shrink();
                            }
                            final t = snapTotals.data!;
                            return Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Depósitos: S/ ${t['total_depositos']?.toStringAsFixed(2) ?? '0.00'}',
                                    ),
                                    Text(
                                      'Préstamos: S/ ${t['total_prestamos']?.toStringAsFixed(2) ?? '0.00'}',
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/admin/caja');
                                  },
                                  child: const Text('Ir a Caja'),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUsuariosTab(),
                _buildDepositosTab(),
                _buildPrestamosTab(),
                _buildFamiliasTab(),
                _buildReportesTab(),
                _buildConfiguracionTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    // Index 0: agregar usuario (ya existente)
    if (_tabController.index == 0) {
      return FloatingActionButton(
        tooltip: 'Agregar usuario',
        child: const Icon(Icons.person_add),
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AdminAddUserScreen()));
        },
      );
    }

    // Index 1: agregar depósito (admin)
    if (_tabController.index == 1) {
      return FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Agregar depósito'),
        onPressed: () => _showAdminCreateDepositoDialog(),
      );
    }

    return null;
  }

  void _showAdminCreateDepositoDialog() {
    final tipoCtrl = TextEditingController(text: 'aporte');
    final montoCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final Set<String> selected = {};
        return StatefulBuilder(
          builder: (ctx2, setState2) {
            return AlertDialog(
              title: const Text('Crear depósito (admin)'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: tipoCtrl.text.isNotEmpty
                          ? tipoCtrl.text
                          : 'aporte',
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: const [
                        DropdownMenuItem(
                          value: 'aporte',
                          child: Text('Aporte'),
                        ),
                        DropdownMenuItem(
                          value: 'aporte_extra',
                          child: Text('Aporte extra'),
                        ),
                        DropdownMenuItem(
                          value: 'certificado',
                          child: Text('Certificado'),
                        ),
                        DropdownMenuItem(
                          value: 'retiro',
                          child: Text('Retiro'),
                        ),
                        DropdownMenuItem(value: 'otro', child: Text('Otro')),
                      ],
                      onChanged: (v) {
                        setState2(() {
                          tipoCtrl.text = v ?? 'aporte';
                        });
                      },
                    ),
                    TextField(
                      controller: montoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Monto total',
                      ),
                    ),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    // WhatsApp group button: reads link from configuración if available
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _configFuture,
                      builder: (context, cfgSnap) {
                        final cfg = cfgSnap.data;
                        final link =
                            (cfg != null
                                    ? (cfg['whatsapp_group'] ??
                                          cfg['whatsapp_link'])
                                    : null)
                                ?.toString();
                        final enabled = link != null && link.isNotEmpty;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            onPressed: enabled
                                ? () async {
                                    try {
                                      final uri = Uri.parse(link);
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      } else {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'No se pudo abrir el enlace de WhatsApp',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error abriendo WhatsApp: ${e.toString()}',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                : null,
                            icon: const Icon(Icons.chat),
                            label: Text(
                              enabled
                                  ? 'Abrir grupo WhatsApp'
                                  : 'Grupo WhatsApp no configurado',
                            ),
                          ),
                        );
                      },
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Seleccionar beneficiarios'),
                    ),
                    Expanded(
                      child: StreamBuilder<List<Usuario>>(
                        stream: _service.streamUsuarios(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final usuarios = snap.data!;
                          return ListView(
                            shrinkWrap: true,
                            children: usuarios.map((u) {
                              final isSelected = selected.contains(u.id);
                              return CheckboxListTile(
                                value: isSelected,
                                title: Text(
                                  u.nombres.isNotEmpty ? u.nombres : u.id,
                                ),
                                subtitle: Text(u.id),
                                onChanged: (v) {
                                  setState2(() {
                                    if (v == true) {
                                      selected.add(u.id);
                                    } else {
                                      selected.remove(u.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          final monto =
                              double.tryParse(montoCtrl.text.trim()) ?? 0.0;
                          if (monto <= 0) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ingrese un monto válido'),
                                ),
                              );
                            }
                            return;
                          }
                          // Distribución con redondeo a 2 decimales (centavos)
                          final n = selected.length;
                          final totalCents = (monto * 100).round();
                          final base = totalCents ~/ n; // cents per user
                          var rem = totalCents % n; // remainder cents
                          final detalle = <Map<String, dynamic>>[];
                          for (final id in selected) {
                            var cents = base;
                            if (rem > 0) {
                              cents += 1;
                              rem -= 1;
                            }
                            detalle.add({
                              'id_usuario': id,
                              'monto': (cents / 100.0),
                            });
                          }
                          try {
                            final adminUid =
                                FirebaseAuth.instance.currentUser?.uid ?? '';
                            AppLogger.info('Admin creando depósito (manual)', {
                              'adminUid': adminUid,
                              'tipo': tipoCtrl.text.trim(),
                              'monto': monto,
                              'beneficiarios': selected.length,
                            });
                            await _service.adminCreateDepositoWithDetalle(
                              tipo: tipoCtrl.text.trim(),
                              monto: monto,
                              descripcion: descCtrl.text.trim(),
                              detalle: detalle,
                              adminUid: adminUid,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Depósito creado y distribuido',
                                  ),
                                ),
                              );
                            }
                            Navigator.of(ctx).pop();
                          } catch (e, st) {
                            AppLogger.error(
                              'Error creando depósito admin',
                              e,
                              st,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                ),
                              );
                            }
                          }
                        },
                  child: const Text('Crear depósito'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateGeneralReport() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final totals = await _service.getAggregateTotals();
      final data = <String, dynamic>{
        'generated_at': DateTime.now().toIso8601String(),
        ...totals,
      };
      final bytes = await PDFService().generateReportPdf(data);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfPreviewScreen(bytes: bytes, filename: 'reporte_general.pdf'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error al generar reporte: ${e.toString()}')),
      );
    }
  }

  // NOTE: For brevity the rest of the backup retains original source and admin logic.
}
PLACEHOLDER - move from lib/screens/admin/admin_dashboard.dart
