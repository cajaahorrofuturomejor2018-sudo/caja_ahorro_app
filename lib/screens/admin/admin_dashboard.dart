// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

import '../../core/services/firestore_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/ml_service.dart';
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
        setState(() {
          _userMap
            ..clear()
            ..addEntries(list.map((u) => MapEntry(u.id, u)));
        });
      },
      onError: (_) {
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
                                title: Text(u.nombres),
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
                          } catch (e) {
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

  Widget _buildPrestamosTab() {
    return StreamBuilder<List<dynamic>>(
      stream: _service.streamPrestamos(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final prestamos = snapshot.data!;
        if (prestamos.isEmpty) {
          return const Center(child: Text('No hay préstamos registrados'));
        }
        return ListView.builder(
          itemCount: prestamos.length,
          itemBuilder: (context, index) {
            final p = prestamos[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.request_page),
                title: Text(
                  '${_userMap[p.idUsuario]?.nombres ?? p.idUsuario} - \$${p.montoSolicitado.toStringAsFixed(2)}',
                ),
                subtitle: Text('Estado: ${p.estado}'),
                onTap: () => _showPrestamoDetalle(p),
              ),
            );
          },
        );
      },
    );
  }

  void _showPrestamoDetalle(dynamic p) async {
    final montoController = TextEditingController(
      text: p.montoSolicitado.toString(),
    );
    final interesController = TextEditingController(text: p.interes.toString());
    final plazoController = TextEditingController(
      text: p.plazoMeses.toString(),
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Detalle préstamo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Solicitante: ${_userMap[p.idUsuario]?.nombres ?? p.idUsuario}',
            ),
            TextField(
              controller: montoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monto a aprobar'),
            ),
            TextField(
              controller: interesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Interés %'),
            ),
            TextField(
              controller: plazoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Plazo (meses)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
              final messenger = ScaffoldMessenger.of(context);
              final dialogNav = Navigator.of(ctx);
              try {
                await _service.approvePrestamo(
                  p.id,
                  adminUid,
                  approve: false,
                  observaciones: 'Rechazado por admin',
                );
                if (context.mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Préstamo rechazado')),
                  );
                }
                dialogNav.pop();
              } catch (e) {
                if (context.mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Rechazar', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
              final messenger = ScaffoldMessenger.of(context);
              final dialogNav = Navigator.of(ctx);
              try {
                // pedir contrato PDF al admin
                final res = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                );
                final montoAprobado =
                    double.tryParse(montoController.text) ?? p.montoSolicitado;
                if (res == null || res.files.single.path == null) {
                  // si no subió contrato, usa la aprobación normal
                  await _service.approvePrestamo(
                    p.id,
                    adminUid,
                    approve: true,
                    montoAprobado: montoAprobado,
                    interes:
                        double.tryParse(interesController.text) ?? p.interes,
                    plazoMeses:
                        int.tryParse(plazoController.text) ?? p.plazoMeses,
                  );
                } else {
                  final localPath = res.files.single.path!;
                  await _service.uploadContratoPdfAndApprove(
                    prestamoId: p.id!,
                    adminUid: adminUid,
                    localContratoPath: localPath,
                    montoAprobado: montoAprobado,
                    observaciones: '',
                  );
                }
                if (context.mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Préstamo aprobado')),
                  );
                }
                dialogNav.pop();
              } catch (e) {
                if (context.mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFamiliasTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.streamFamilias(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final familias = snapshot.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Crear familia'),
                onPressed: () => _createFamiliaDialog(),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: familias.length,
                itemBuilder: (context, index) {
                  final f = familias[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.group),
                      title: Text(f['nombre_grupo'] ?? ''),
                      subtitle: Text(
                        'Miembros: ${(f['miembros'] as List<dynamic>?)?.length ?? 0} • Total: \$${(f['total_grupo'] ?? 0).toString()}',
                      ),
                      onTap: () => _editFamiliaDialog(f),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _createFamiliaDialog() {
    final nameCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final Set<String> selected = {};
        return StatefulBuilder(
          builder: (ctx2, setState2) {
            return AlertDialog(
              title: const Text('Crear familia'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del grupo',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Seleccionar miembros'),
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
                                title: Text(u.nombres),
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
                          final payload = {
                            'nombre_grupo': nameCtrl.text,
                            'miembros': selected
                                .map(
                                  (id) => {
                                    'id_usuario': id,
                                    'rol_familiar': 'miembro',
                                  },
                                )
                                .toList(),
                            'total_grupo': 0.0,
                          };
                          try {
                            final dialogNav = Navigator.of(ctx);
                            final messenger = ScaffoldMessenger.of(ctx);
                            await _service.createFamilia(payload);
                            if (context.mounted) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Familia creada')),
                              );
                            }
                            dialogNav.pop();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                ),
                              );
                            }
                          }
                        },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editFamiliaDialog(Map<String, dynamic> f) {
    final nameCtrl = TextEditingController(text: f['nombre_grupo'] ?? '');
    final existing =
        (f['miembros'] as List<dynamic>?)
            ?.map(
              (e) =>
                  e is Map ? (e['id_usuario'] ?? '').toString() : e.toString(),
            )
            .where((s) => s.isNotEmpty)
            .toSet() ??
        <String>{};

    showDialog<void>(
      context: context,
      builder: (ctx) {
        final Set<String> selected = Set<String>.from(existing);
        return StatefulBuilder(
          builder: (ctx2, setState2) {
            return AlertDialog(
              title: const Text('Editar familia'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del grupo',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Seleccionar miembros'),
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
                                title: Text(u.nombres),
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
                  onPressed: () async {
                    final payload = {
                      'nombre_grupo': nameCtrl.text,
                      'miembros': selected
                          .map(
                            (id) => {
                              'id_usuario': id,
                              'rol_familiar': 'miembro',
                            },
                          )
                          .toList(),
                    };
                    try {
                      final dialogNav = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(ctx);
                      await _service.updateFamilia(f['id'], payload);
                      if (context.mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Familia actualizada')),
                        );
                      }
                      dialogNav.pop();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error: ${e.toString()}')),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildUsuariosTab() {
    return StreamBuilder<List<Usuario>>(
      stream: _service.streamUsuarios(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final usuarios = snapshot.data!;
        if (usuarios.isEmpty) {
          return const Center(child: Text('No hay usuarios registrados'));
        }
        return ListView.builder(
          itemCount: usuarios.length,
          itemBuilder: (context, index) {
            final u = usuarios[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(u.nombres),
                subtitle: Text('${u.rol} • ${u.correo}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await _service.setUserRole(u.id, value);
                          if (context.mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Rol actualizado a $value'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'admin',
                          child: Text('Hacer admin'),
                        ),
                        PopupMenuItem(
                          value: 'cliente',
                          child: Text('Hacer cliente'),
                        ),
                      ],
                      icon: const Icon(Icons.settings),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: u.estado == 'activo',
                      onChanged: (v) async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await _service.setUserEstado(
                            u.id,
                            v ? 'activo' : 'inactivo',
                          );
                          if (context.mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Estado actualizado')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
                onTap: () => _showUsuarioDetalle(u),
              ),
            );
          },
        );
      },
    );
  }

  void _showUsuarioDetalle(Usuario u) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(u.nombres),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Correo: ${u.correo}'),
            Text('Rol: ${u.rol}'),
            Text('Estado: ${u.estado}'),
            const SizedBox(height: 8),
            Text('Ahorros: \$${u.totalAhorros.toStringAsFixed(2)}'),
            Text('Préstamos: \$${u.totalPrestamos.toStringAsFixed(2)}'),
            Text('Multas: \$${u.totalMultas.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositosTab() {
    return StreamBuilder<List<Deposito>>(
      stream: _service.streamAllDepositos(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Mostrar error legible en la UI y permitir reintentar
          final err = snapshot.error;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Error cargando depósitos: ${err.toString()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Esto suele ocurrir por permisos de Firestore o por App Check.\nPuedes revisar las reglas de seguridad o reintentar.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  onPressed: () => setState(() {}),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final deps = snapshot.data!;
        if (deps.isEmpty) {
          return const Center(child: Text('No hay depósitos registradas'));
        }
        return ListView.builder(
          itemCount: deps.length,
          itemBuilder: (context, index) {
            final d = deps[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.attach_money),
                title: Text('${d.tipo} - \$${d.monto.toStringAsFixed(2)}'),
                subtitle: Text(
                  '${d.fechaDeposito.toLocal()} • user: ${_userMap[d.idUsuario]?.nombres ?? d.idUsuario}',
                ),
                onTap: () => _showDepositoDetalle(d),
                trailing: TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    if (d.id == null) {
                      if (context.mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'No se puede validar: id de depósito desconocido',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    try {
                      // Usar flujo transaccional de aprobación para distribuir montos
                      final adminUid = FirebaseAuth.instance.currentUser?.uid;
                      if (adminUid == null) {
                        throw Exception('No se pudo obtener id de admin');
                      }
                      await _service.approveDeposito(
                        d.id!,
                        adminUid,
                        approve: true,
                      );
                      if (context.mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Depósito aprobado y distribuido'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error al aprobar depósito: ${e.toString()}',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(d.validado ? 'Validado' : 'Validar'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDepositoDetalle(Deposito d) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = await _service.getDepositoById(d.id ?? '');
    if (data == null) {
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se encontró el depósito')),
        );
      }
      return;
    }

    final archivo = data['archivo_url'] as String?;
    final descripcion = data['descripcion'] as String? ?? '';
    // Parse detalle_por_usuario defensivamente: elements may be Map or JSON-encoded String
    List<Map<String, dynamic>>? detalle;
    final rawDetalle = data['detalle_por_usuario'];
    if (rawDetalle is List) {
      detalle = [];
      for (final e in rawDetalle) {
        if (e is Map) {
          detalle.add(Map<String, dynamic>.from(e));
        } else if (e is String) {
          try {
            final dec = jsonDecode(e);
            if (dec is Map) detalle.add(Map<String, dynamic>.from(dec));
          } catch (_) {
            // ignore malformed entries
          }
        }
      }
    }

    final obsController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Depósito - \$${(data['monto'] ?? 0).toString()}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (archivo != null && archivo.isNotEmpty) ...[
                SizedBox(
                  height: 180,
                  child: Center(
                    child: Image.network(
                      archivo,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stack) =>
                          const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text('Tipo: ${data['tipo'] ?? ''}'),
              Text(
                'Usuario: ${_userMap[(data['id_usuario'] ?? '')]?.nombres ?? (data['id_usuario'] ?? '')}',
              ),
              Text('Fecha: ${data['fecha_deposito'] ?? ''}'),
              const SizedBox(height: 8),
              Text('Descripción: $descripcion'),
              const SizedBox(height: 8),
              const Text('Detalle por usuario:'),
              if (detalle == null || detalle.isEmpty)
                const Text(' - No especificado (usar id_usuario)'),
              if (detalle != null)
                ...detalle.map(
                  (p) => Text(
                    '- ${_userMap[(p['id_usuario'] ?? '')]?.nombres ?? (p['id_usuario'] ?? '')}: \$${(p['monto'] ?? 0)}',
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: obsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observaciones (opcional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          if (archivo != null && archivo.isNotEmpty)
            TextButton(
              onPressed: () async {
                final parentContext = context;
                final messenger = ScaffoldMessenger.of(parentContext);
                try {
                  final ocr = await _ml.analyzeImageFromUrl(archivo);
                  final fields = _ml.extractFields(ocr);
                  if (!mounted) return;
                  await showDialog<void>(
                    context: parentContext,
                    builder: (_) => AlertDialog(
                      title: const Text('Resultado OCR'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Texto detectado:'),
                          const SizedBox(height: 8),
                          Text(
                            ocr,
                            maxLines: 10,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Divider(),
                          Text('Monto: ${fields['monto'] ?? 'N/A'}'),
                          Text('Fecha: ${fields['fecha'] ?? 'N/A'}'),
                          Text('Cuenta: ${fields['cuenta'] ?? 'N/A'}'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(parentContext).pop(),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error OCR: ${e.toString()}')),
                  );
                }
              },
              child: const Text('Analizar voucher'),
            ),
          TextButton(
            onPressed: () async {
              final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
              final messenger = ScaffoldMessenger.of(context);
              final dialogNav = Navigator.of(ctx);
              try {
                await _service.approveDeposito(
                  d.id!,
                  adminUid,
                  approve: false,
                  observaciones: obsController.text,
                );
                if (context.mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Depósito rechazado')),
                  );
                }
                dialogNav.pop();
              } catch (e) {
                if (context.mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Rechazar', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
              final messenger = ScaffoldMessenger.of(context);
              final dialogNav = Navigator.of(ctx);
              try {
                await _service.approveDeposito(
                  d.id!,
                  adminUid,
                  approve: true,
                  observaciones: obsController.text,
                  detalleOverride: detalle,
                );
                if (context.mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Depósito aprobado')),
                  );
                }
                dialogNav.pop();
              } catch (e) {
                if (context.mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportesTab() {
    return FutureBuilder<Map<String, double>>(
      future: _service.getAggregateTotals(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final totals = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total depósitos: \$${totals['total_depositos']!.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Total préstamos aprobados: \$${totals['total_prestamos']!.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Exportar reporte general (PDF)'),
                onPressed: () async {
                  final pdfService = PDFService();
                  final parentNav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final data = {
                      'total_depositos': totals['total_depositos'],
                      'total_prestamos': totals['total_prestamos'],
                      'generated_at': DateTime.now().toIso8601String(),
                    };
                    final bytes = await pdfService.generateReportPdf(data);
                    if (!mounted) return;
                    await parentNav.push(
                      MaterialPageRoute(
                        builder: (_) => PdfPreviewScreen(
                          bytes: bytes,
                          filename:
                              'reporte_general_${DateTime.now().millisecondsSinceEpoch}.pdf',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (context.mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error generando PDF: ${e.toString()}'),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfiguracionTab() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _configFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          // Mostrar error y permitir reintentar o introducir manualmente valores
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error cargando configuración: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  onPressed: () => setState(
                    () => _configFuture = _service.getConfiguracion(),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'También puedes ingresar valores manualmente abajo.',
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildConfiguracionForm({}, context),
                  ),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data ?? {};

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildConfiguracionForm(data, context),
        );
      },
    );
  }

  // Extraer formulario para poder reutilizarlo cuando hay error o data nula
  Widget _buildConfiguracionForm(
    Map<String, dynamic> data,
    BuildContext context,
  ) {
    final interesCuotas = TextEditingController(
      text: (data['interes_cuotas'] ?? '').toString(),
    );
    final interesPlazo = TextEditingController(
      text: (data['interes_plazo_fijo'] ?? '').toString(),
    );
    final interesCert = TextEditingController(
      text: (data['interes_certificados'] ?? '').toString(),
    );
    final multaDiaria = TextEditingController(
      text: (data['multa_diaria'] ?? '').toString(),
    );
    final accountNameCtrl = TextEditingController(
      text: (data['account_name'] ?? '').toString(),
    );
    final accountNumberCtrl = TextEditingController(
      text: (data['account_number'] ?? '').toString(),
    );
    final dueScheduleCtrl = TextEditingController(
      text: (data['due_schedule_json'] ?? data['due_schedule'] ?? '')
          .toString(),
    );
    final graceDaysCtrl = TextEditingController(
      text: (data['grace_days'] ?? '').toString(),
    );
    final penaltyTypeCtrl = TextEditingController(
      text: (data['penalty']?['type'] ?? 'percent').toString(),
    );
    final penaltyValueCtrl = TextEditingController(
      text: (data['penalty']?['value'] ?? '').toString(),
    );
    bool voucherBlockEnabled =
        (data['voucher_reuse_block']?['enabled'] ?? false) as bool;
    final voucherTtlCtrl = TextEditingController(
      text: (data['voucher_reuse_block']?['ttl_days'] ?? '').toString(),
    );
    bool enforceVoucherDate = (data['enforce_voucher_date'] ?? false) as bool;
    final matchLastDigitsCtrl = TextEditingController(
      text: (data['ocr']?['match_last_digits'] ?? 3).toString(),
    );
    final diasAlerta = TextEditingController(
      text: (data['dias_alerta'] ?? []).join(','),
    );
    final limiteInactividad = TextEditingController(
      text: (data['limite_inactividad'] ?? '').toString(),
    );
    final maxAdmins = TextEditingController(
      text: (data['max_admins'] ?? '').toString(),
    );
    final whatsappCtrl = TextEditingController(
      text: (data['whatsapp_group'] ?? data['whatsapp_link'] ?? '').toString(),
    );

    return ListView(
      children: [
        TextField(
          controller: interesCuotas,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Interés cuotas (%)'),
        ),
        TextField(
          controller: interesPlazo,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Interés plazo fijo (%)',
          ),
        ),
        TextField(
          controller: interesCert,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Interés certificados (%)',
          ),
        ),
        TextField(
          controller: multaDiaria,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Multa diaria'),
        ),
        TextField(
          controller: diasAlerta,
          decoration: const InputDecoration(
            labelText: 'Días alerta (csv, ej: 7,4,0)',
          ),
        ),
        TextField(
          controller: limiteInactividad,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Límite inactividad (minutos)',
          ),
        ),
        TextField(
          controller: maxAdmins,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Max admins'),
        ),
        TextField(
          controller: whatsappCtrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Enlace grupo WhatsApp (chat.whatsapp.com/...)',
          ),
        ),
        const SizedBox(height: 12),
        const Divider(),
        const Text(
          'Cobranza / Vouchers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: accountNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre de cuenta (visible)',
          ),
        ),
        TextField(
          controller: accountNumberCtrl,
          decoration: const InputDecoration(
            labelText: 'Número de cuenta (completo)',
          ),
        ),
        TextField(
          controller: dueScheduleCtrl,
          decoration: const InputDecoration(
            labelText: 'Fechas límite (JSON o CSV) - e.g {"1":"2025-10-05"}',
          ),
        ),
        TextField(
          controller: graceDaysCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Días de gracia antes de multa',
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: penaltyTypeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tipo de multa (percent|fixed)',
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: TextField(
                controller: penaltyValueCtrl,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor'),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Checkbox(
              value: voucherBlockEnabled,
              onChanged: (v) {
                setState(() {
                  voucherBlockEnabled = v ?? false;
                });
              },
            ),
            const SizedBox(width: 6),
            const Text('Bloquear reuse de voucher (configurable)'),
          ],
        ),
        TextField(
          controller: voucherTtlCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Voucher TTL (días) si aplica',
          ),
        ),
        Row(
          children: [
            const Text('Exigir fecha válida en voucher:'),
            const SizedBox(width: 8),
            Switch(
              value: enforceVoucherDate,
              onChanged: (v) {
                setState(() {
                  enforceVoucherDate = v;
                });
              },
            ),
          ],
        ),
        TextField(
          controller: matchLastDigitsCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Dígitos para verificar cuenta (últimos)',
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
            final payload = <String, dynamic>{
              'interes_cuotas': double.tryParse(interesCuotas.text) ?? 0.0,
              'interes_plazo_fijo': double.tryParse(interesPlazo.text) ?? 0.0,
              'interes_certificados': double.tryParse(interesCert.text) ?? 0.0,
              'multa_diaria': double.tryParse(multaDiaria.text) ?? 0.0,
              'dias_alerta': diasAlerta.text
                  .split(',')
                  .map((s) => int.tryParse(s.trim()) ?? 0)
                  .toList(),
              'limite_inactividad': int.tryParse(limiteInactividad.text) ?? 30,
              'max_admins': int.tryParse(maxAdmins.text) ?? 1,
              'whatsapp_group': whatsappCtrl.text.trim(),
              // Cobranza
              'account_name': accountNameCtrl.text.trim(),
              'account_number': accountNumberCtrl.text.trim(),
              'due_schedule_json': dueScheduleCtrl.text.trim(),
              'grace_days': int.tryParse(graceDaysCtrl.text) ?? 0,
              'penalty': {
                'type': penaltyTypeCtrl.text.trim(),
                'value': double.tryParse(penaltyValueCtrl.text) ?? 0.0,
              },
              'voucher_reuse_block': {
                'enabled': voucherBlockEnabled,
                'ttl_days': int.tryParse(voucherTtlCtrl.text) ?? 0,
              },
              'enforce_voucher_date': enforceVoucherDate,
              'ocr': {
                'match_last_digits':
                    int.tryParse(matchLastDigitsCtrl.text) ?? 3,
              },
            };
            try {
              final messenger = ScaffoldMessenger.of(context);
              await _service.setConfiguracion(payload, adminUid);
              if (context.mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Configuración guardada')),
                );
                setState(() => _configFuture = _service.getConfiguracion());
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error guardando configuración: ${e.toString()}',
                    ),
                  ),
                );
              }
            }
          },
          child: const Text('Guardar configuración'),
        ),
      ],
    );
  }
}
