import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/firestore_service.dart';
// models not required directly in this form

class PrestamoForm extends StatefulWidget {
  const PrestamoForm({super.key});

  @override
  State<PrestamoForm> createState() => _PrestamoFormState();
}

class _PrestamoFormState extends State<PrestamoForm> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _mesesCtrl = TextEditingController();
  String _tipo = 'consumo';
  String? _certificadoPath;
  bool _loading = false;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _mesesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar préstamo')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _montoCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto solicitado',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingrese el monto' : null,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                items: const [
                  DropdownMenuItem(value: 'consumo', child: Text('Consumo')),
                  DropdownMenuItem(value: 'personal', child: Text('Personal')),
                  DropdownMenuItem(
                    value: 'hipotecario',
                    child: Text('Hipotecario'),
                  ),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? 'consumo'),
                decoration: const InputDecoration(
                  labelText: 'Tipo de préstamo',
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _mesesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Plazo en meses',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingrese el plazo' : null,
              ),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text(
                  'Adjuntar PDF (buro/ certificado) — obligatorio',
                ),
                onPressed: () async {
                  final res = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf'],
                  );
                  if (res != null && res.files.single.path != null) {
                    setState(() => _certificadoPath = res.files.single.path);
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(
                _certificadoPath == null
                    ? 'No se adjuntó PDF (es obligatorio)'
                    : 'PDF adjuntado',
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (_certificadoPath == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Adjunte el PDF obligatorio (buro/certificado)',
                        ),
                      ),
                    );
                    return;
                  }
                  final uid = FirebaseAuth.instance.currentUser!.uid;
                  // Capturamos referencias que no dependan del BuildContext después
                  // de operaciones async para evitar use_build_context_synchronously.
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  setState(() => _loading = true);
                  try {
                    await service.createPrestamoWithCert(
                      idUsuario: uid,
                      montoSolicitado: double.parse(_montoCtrl.text),
                      interes: 0.0,
                      plazoMeses: int.parse(_mesesCtrl.text),
                      certificadoLocalPath: _certificadoPath,
                      tipo: _tipo,
                    );
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Solicitud enviada')),
                    );
                    navigator.pop();
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  } finally {
                    setState(() => _loading = false);
                  }
                },
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Enviar solicitud'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
