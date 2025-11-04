import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/firestore_service.dart';
import '../../models/prestamo.dart';
import 'package:url_launcher/url_launcher.dart';

class MisPrestamosScreen extends StatefulWidget {
  const MisPrestamosScreen({super.key});

  @override
  State<MisPrestamosScreen> createState() => _MisPrestamosScreenState();
}

class _MisPrestamosScreenState extends State<MisPrestamosScreen> {
  String _selectedEstado = 'todos';
  String _selectedTipo = 'todos';
  String _searchQuery = '';
  bool _showErrorDetails = false;
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final fs = FirestoreService();
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('No autenticado')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mis préstamos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedEstado,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: const [
                      DropdownMenuItem(value: 'todos', child: Text('Todos')),
                      DropdownMenuItem(
                        value: 'pendiente',
                        child: Text('Pendiente'),
                      ),
                      DropdownMenuItem(
                        value: 'aprobado',
                        child: Text('Aprobado'),
                      ),
                      DropdownMenuItem(value: 'activo', child: Text('Activo')),
                      DropdownMenuItem(value: 'pagado', child: Text('Pagado')),
                      DropdownMenuItem(
                        value: 'rechazado',
                        child: Text('Rechazado'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedEstado = v ?? 'todos'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar (tipo/id)',
                    ),
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.trim().toLowerCase()),
                  ),
                ),
              ],
            ),
          ),
          // Tipo filter will be a horizontal chips list generated from data
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                const Text('Tipo:'),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: StreamBuilder<List<Prestamo>>(
                      stream: fs.getPrestamos(uid),
                      builder: (context, snapTypes) {
                        final tipos = <String>{'todos'};
                        if (snapTypes.hasData) {
                          for (final p in snapTypes.data!) {
                            if (p.tipo != null && p.tipo!.isNotEmpty) {
                              tipos.add(p.tipo!);
                            }
                          }
                        }
                        final chips = tipos.map((t) {
                          final selected = _selectedTipo == t;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(t == 'todos' ? 'Todos' : t),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _selectedTipo = t),
                            ),
                          );
                        }).toList();
                        return Row(children: chips);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Prestamo>>(
              stream: fs.getPrestamos(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  final err = snap.error?.toString() ?? 'Error desconocido';
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No se pueden cargar los préstamos debido a permisos de acceso.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Esto normalmente ocurre cuando la cuenta actual no tiene permiso para leer los datos en Firestore o falta configurar el Emulator/AppCheck en desarrollo.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => setState(() {}),
                              child: const Text('Reintentar'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => setState(
                                () => _showErrorDetails = !_showErrorDetails,
                              ),
                              child: Text(
                                _showErrorDetails
                                    ? 'Ocultar detalles'
                                    : 'Ver detalles',
                              ),
                            ),
                          ],
                        ),
                        if (_showErrorDetails) ...[
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            child: Text(
                              err,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var prestamos = snap.data!;
                if (prestamos.isEmpty) {
                  return const Center(child: Text('No tiene préstamos'));
                }

                // Aplicar filtros locales
                prestamos = prestamos.where((p) {
                  if (_selectedEstado != 'todos' &&
                      p.estado != _selectedEstado) {
                    return false;
                  }
                  if (_selectedTipo != 'todos' &&
                      (p.tipo ?? '') != _selectedTipo) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final hayTipo = (p.tipo ?? '').toLowerCase().contains(
                      _searchQuery,
                    );
                    final hayId = (p.id ?? '').toLowerCase().contains(
                      _searchQuery,
                    );
                    final hayMonto = p.montoSolicitado
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery);
                    if (!(hayTipo || hayId || hayMonto)) return false;
                  }
                  return true;
                }).toList();

                if (prestamos.isEmpty) {
                  return const Center(
                    child: Text('No hay préstamos con esos filtros'),
                  );
                }

                return ListView.separated(
                  itemCount: prestamos.length,
                  separatorBuilder: (ctx, index) => const Divider(),
                  itemBuilder: (context, i) {
                    final p = prestamos[i];
                    return ListTile(
                      leading: const Icon(Icons.request_page),
                      title: Text(
                        '\$${p.montoSolicitado.toStringAsFixed(2)} • ${p.estado} • ${p.tipo ?? ''}',
                      ),
                      subtitle: Text(
                        'Plazo: ${p.plazoMeses} meses • Cuota: ${p.cuotaMensual?.toStringAsFixed(2) ?? '-'}',
                      ),
                      trailing: p.contratoPdfUrl != null
                          ? IconButton(
                              icon: const Icon(Icons.picture_as_pdf),
                              onPressed: () async {
                                final url = p.contratoPdfUrl!;
                                final uri = Uri.parse(url);
                                final messenger = ScaffoldMessenger.of(context);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                } else {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No se pudo abrir contrato',
                                      ),
                                    ),
                                  );
                                }
                              },
                            )
                          : null,
                      onTap: () => _showDetalle(context, p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDetalle(BuildContext context, Prestamo p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detalle préstamo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monto solicitado: \$${p.montoSolicitado}'),
            Text('Monto aprobado: \$${p.montoAprobado ?? '-'}'),
            Text('Estado: ${p.estado}'),
            Text('Cuota mensual: ${p.cuotaMensual?.toStringAsFixed(2) ?? '-'}'),
            if (p.certificadoPdfUrl != null)
              TextButton.icon(
                onPressed: () {
                  final uri = Uri.parse(p.certificadoPdfUrl!);
                  canLaunchUrl(uri).then((ok) {
                    if (ok) launchUrl(uri);
                  });
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Ver certificado'),
              ),
            if (p.contratoPdfUrl != null)
              TextButton.icon(
                onPressed: () {
                  final uri = Uri.parse(p.contratoPdfUrl!);
                  canLaunchUrl(uri).then((ok) {
                    if (ok) launchUrl(uri);
                  });
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Ver contrato'),
              ),
          ],
        ),
        actions: [
          if (p.estado == 'aprobado' || p.estado == 'activo')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // abrir el diálogo de pago en la siguiente microtarea para
                // evitar usar el mismo BuildContext a través de un gap async.
                // ignore: use_build_context_synchronously
                Future.microtask(() => _showPagarDialog(context, p));
              },
              child: const Text('Pagar cuota'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPagarDialog(BuildContext context, Prestamo p) async {
    final montoCtrl = TextEditingController(
      text: p.cuotaMensual?.toStringAsFixed(2) ?? '0',
    );
    final descripcionCtrl = TextEditingController(text: 'Pago cuota');
    final fs = FirestoreService();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pagar cuota'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: montoCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto'),
            ),
            TextField(
              controller: descripcionCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final monto = double.tryParse(montoCtrl.text) ?? 0.0;
              final pago = {
                'monto': monto,
                'fecha': DateTime.now(),
                'descripcion': descripcionCtrl.text,
                'registrado_por': uid,
              };
              try {
                await fs.addPagoPrestamo(p.id!, pago);
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Pago registrado')),
                );
                navigator.pop();
              } catch (e) {
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            child: const Text('Pagar'),
          ),
        ],
      ),
    );
  }
}
