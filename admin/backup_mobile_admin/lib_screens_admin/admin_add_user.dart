// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/auth_service.dart';

class AdminAddUserScreen extends StatefulWidget {
  const AdminAddUserScreen({super.key});

  @override
  State<AdminAddUserScreen> createState() => _AdminAddUserScreenState();
}

class _AdminAddUserScreenState extends State<AdminAddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _fotoCtrl = TextEditingController();
  String _rol = 'cliente';
  String _estado = 'activo';
  bool _processing = false;

  final AuthService _auth = AuthService();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _passwordCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _fotoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _processing = true);
    try {
      // Antes de crear el usuario, pedimos la contraseña del admin actual
      final current = FirebaseAuth.instance.currentUser;
      String? adminEmail = current?.email;
      String? adminPassword;
      if (adminEmail != null) {
        // Pedimos contraseña para poder volver a autenticarnos después de crear el usuario
        adminPassword = await showDialog<String?>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            final pwCtrl = TextEditingController();
            return AlertDialog(
              title: const Text('Confirmar acción (admin)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ingrese su contraseña para confirmar creación de usuario',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pwCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña admin',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(pwCtrl.text),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
        if (adminPassword == null || adminPassword.isEmpty) {
          // Usuario canceló la confirmación
          if (mounted) setState(() => _processing = false);
          return;
        }
      }

      final user = await _auth.register(
        nombre: _nombreCtrl.text.trim(),
        correo: _correoCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        rol: _rol,
        telefono: _telefonoCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
        estado: _estado,
        fotoUrl: _fotoCtrl.text.trim().isEmpty ? null : _fotoCtrl.text.trim(),
      );
      if (!mounted) return;
      if (user != null) {
        // Tras la creación, la SDK cliente hace sign-in como el nuevo usuario.
        // Reautenticamos al admin usando la contraseña que ingresó para restaurar la sesión.
        if (adminEmail != null) {
          try {
            await _auth.login(adminEmail, adminPassword!);
          } catch (e) {
            // Si falla la reautenticación, advertimos al admin para que cierre sesión manualmente.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Usuario creado, pero no se pudo restaurar la sesión admin: ${e.toString()}',
                ),
              ),
            );
            // No retornamos aquí: el usuario fue creado correctamente.
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario creado con éxito')),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo crear el usuario')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar usuario')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombres'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingrese el nombre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _correoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingrese el correo' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                validator: (v) => v == null || v.length < 6
                    ? 'La contraseña debe tener al menos 6 caracteres'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonoCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
                validator: (v) => null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _direccionCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
                validator: (v) => null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fotoCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL foto (opcional)',
                  hintText: 'https://...',
                ),
                keyboardType: TextInputType.url,
                validator: (v) => null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _estado,
                items: const [
                  DropdownMenuItem(value: 'activo', child: Text('Activo')),
                  DropdownMenuItem(value: 'inactivo', child: Text('Inactivo')),
                ],
                onChanged: (v) => setState(() => _estado = v ?? 'activo'),
                decoration: const InputDecoration(labelText: 'Estado'),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _rol,
                items: const [
                  DropdownMenuItem(value: 'cliente', child: Text('Cliente')),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Administrador'),
                  ),
                ],
                onChanged: (v) => setState(() => _rol = v ?? 'cliente'),
                decoration: const InputDecoration(labelText: 'Rol'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _processing ? null : _submit,
                child: _processing
                    ? const CircularProgressIndicator()
                    : const Text('Crear usuario'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
