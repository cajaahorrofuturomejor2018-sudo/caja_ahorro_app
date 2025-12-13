import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/firestore_service.dart';
import '../../models/usuario.dart';

class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombresCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  File? _pickedImage;
  bool _saving = false;
  Usuario? _usuario;
  final _service = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final u = await _service.getUsuario(uid);
    if (!mounted) return;
    setState(() {
      _usuario = u;
      _nombresCtrl.text = u?.nombres ?? '';
      _telefonoCtrl.text = u?.telefono ?? '';
      _direccionCtrl.text = u?.direccion ?? '';
    });
  }

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String? fotoUrl = _usuario?.fotoUrl;
      if (_pickedImage != null) {
        final ref = FirebaseStorage.instance.ref().child(
          'usuarios/$uid/profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await ref.putFile(_pickedImage!);
        fotoUrl = await ref.getDownloadURL();
      }
      final payload = <String, dynamic>{
        'nombres': _nombresCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'direccion': _direccionCtrl.text.trim(),
      };
      if (fotoUrl != null && fotoUrl.isNotEmpty) payload['foto_url'] = fotoUrl;
      await _service.updateUsuario(uid, payload);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Perfil actualizado')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _usuario == null
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Center(
                      child: Column(
                        children: [
                          if ((_usuario?.fotoUrl ?? '').isNotEmpty)
                            CircleAvatar(
                              radius: 48,
                              backgroundImage: NetworkImage(_usuario!.fotoUrl!),
                            )
                          else
                            const CircleAvatar(
                              radius: 48,
                              child: Icon(Icons.person, size: 48),
                            ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.image),
                            label: const Text('Cambiar foto'),
                            onPressed: () async {
                              final ImagePicker picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1200,
                                imageQuality: 85,
                              );
                              if (picked != null) {
                                setState(
                                  () => _pickedImage = File(picked.path),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nombresCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombres y apellidos',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Ingrese nombres' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _telefonoCtrl,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _direccionCtrl,
                      decoration: const InputDecoration(labelText: 'Dirección'),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Guardar cambios'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
