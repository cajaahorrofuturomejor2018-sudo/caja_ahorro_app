import 'package:flutter/material.dart';
import '/core/services/auth_service.dart';
import '/widgets/custom_button.dart';
import '/widgets/custom_input.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  String rol = 'cliente';
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return Scaffold(
      appBar: AppBar(title: const Text("Registro")),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: SingleChildScrollView(
          child: Column(
            children: [
              CustomInput(
                controller: nameCtrl,
                hintText: "Nombre completo",
                icon: Icons.person,
              ),
              const SizedBox(height: 15),
              CustomInput(
                controller: emailCtrl,
                hintText: "Correo electrónico",
                icon: Icons.email,
              ),
              const SizedBox(height: 15),
              CustomInput(
                controller: passCtrl,
                hintText: "Contraseña",
                icon: Icons.lock,
                obscureText: true,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Rol",
                ),
                initialValue: rol,
                items: const [
                  DropdownMenuItem(value: 'cliente', child: Text('Cliente')),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Administrador'),
                  ),
                ],
                onChanged: (value) => setState(() => rol = value!),
              ),
              const SizedBox(height: 25),
              CustomButton(
                text: "Registrar",
                loading: loading,
                onPressed: () async {
                  setState(() => loading = true);
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  try {
                    await auth.register(
                      nombre: nameCtrl.text.trim(),
                      correo: emailCtrl.text.trim(),
                      password: passCtrl.text.trim(),
                      rol: rol,
                    );
                    if (!mounted) return;
                    navigator.pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text("Error: ${e.toString()}")),
                    );
                  }
                  setState(() => loading = false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
