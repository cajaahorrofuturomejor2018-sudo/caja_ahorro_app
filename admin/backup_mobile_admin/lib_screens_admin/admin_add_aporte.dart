import 'package:flutter/material.dart';

import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/usuario.dart';

class AdminAddAporteScreen extends StatefulWidget {
  const AdminAddAporteScreen({super.key});

  @override
  State<AdminAddAporteScreen> createState() => _AdminAddAporteScreenState();
}

class _AdminAddAporteScreenState extends State<AdminAddAporteScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedUserId;
  String _tipo = 'aporte';
  final _montoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _archivoCtrl = TextEditingController();
  bool _processing = false;

  final FirestoreService _service = FirestoreService();
  final AuthService _auth = AuthService();

  @override
  void dispose() {
    _montoCtrl.dispose();
    _descripcionCtrl.dispose();
    _archivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleccione un usuario')));
      return;
    }
    setState(() {
      _processing = true;
    });
    try {
      final monto = double.tryParse(_montoCtrl.text.trim()) ?? 0.0;
      // adminUid: using current auth user id if available
      final adminUid = _auth.currentUser?.uid ?? '';
      await _service.adminAddAporte(
        idUsuario: _selectedUserId!,
        tipo: _tipo,
        monto: monto,
        descripcion: _descripcionCtrl.text.trim(),
        archivoUrl: _archivoCtrl.text.trim().isEmpty
            ? null
            : _archivoCtrl.text.trim(),
        adminUid: adminUid,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aporte registrado con éxito')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar aporte (admin)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Usuario>>(
                stream: _service.streamUsuarios(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users = snap.data!;
                  return Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                          ),
                          items: users
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u.id,
                                  child: Text(
                                    '${u.nombres.isNotEmpty ? u.nombres : u.id} - ${u.correo}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _selectedUserId = v),
                          validator: (v) =>
                              v == null ? 'Seleccione un usuario' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _tipo,
                          decoration: const InputDecoration(labelText: 'Tipo'),
                          items: const [
                            DropdownMenuItem(
                              value: 'aporte',
                              child: Text('Aporte'),
                            ),
                            DropdownMenuItem(
                              value: 'donacion',
                              child: Text('Donación'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _tipo = v ?? 'aporte'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _montoCtrl,
                          decoration: const InputDecoration(labelText: 'Monto'),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) =>
                              (v == null || double.tryParse(v) == null)
                              ? 'Ingrese un monto válido'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descripcionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Descripción (opcional)',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _archivoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'URL voucher (opcional)',
                          ),
                          keyboardType: TextInputType.url,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _processing ? null : _submit,
                child: _processing
                    ? const CircularProgressIndicator()
                    : const Text('Registrar aporte'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
