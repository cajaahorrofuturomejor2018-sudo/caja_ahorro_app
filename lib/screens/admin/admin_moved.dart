import 'package:flutter/material.dart';
import 'admin_reportes.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel del Administrador')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'La administración se realiza desde la aplicación web (admin).',
          ),
        ),
      ),
    );
  }
}

class AdminAddUserScreen extends StatelessWidget {
  const AdminAddUserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar usuario (admin)')),
      body: const Center(child: Text('Crear usuarios desde admin web.')),
    );
  }
}

class AdminAddAporteScreen extends StatelessWidget {
  const AdminAddAporteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar aporte (admin)')),
      body: const Center(child: Text('Registrar aportes desde admin web.')),
    );
  }
}

class AdminCaja extends StatelessWidget {
  const AdminCaja({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caja (admin)')),
      body: const Center(child: Text('Administrar caja desde admin web.')),
    );
  }
}

class AdminValidaciones extends StatelessWidget {
  const AdminValidaciones({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Validaciones')),
      body: const Center(child: Text('Validaciones desde admin web.')),
    );
  }
}

class AuditoriaScreen extends StatelessWidget {
  const AuditoriaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auditoría')),
      body: const Center(child: Text('Auditoría en admin web.')),
    );
  }
}

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: const Center(child: Text('Configuración en admin web.')),
    );
  }
}

class ReporteScreen extends StatelessWidget {
  const ReporteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminReportesScreen();
  }
}
