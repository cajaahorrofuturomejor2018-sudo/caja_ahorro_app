import 'package:flutter/material.dart';
import '../../core/services/config_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final configService = ConfigService();

  final tasaCtrl = TextEditingController();
  final multaCtrl = TextEditingController();
  final limiteCtrl = TextEditingController();
  final ahorroCtrl = TextEditingController();
  final plazosCtrl = TextEditingController();

  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await configService.initConfig();
    final data = await configService.getConfig();
    if (data != null) {
      tasaCtrl.text = data['tasa_interes_anual'].toString();
      multaCtrl.text = data['porcentaje_multa'].toString();
      limiteCtrl.text = data['limite_prestamo'].toString();
      ahorroCtrl.text = data['min_ahorro'].toString();
      plazosCtrl.text = (data['plazos_fijos'] as List).join(',');
    }
    setState(() => cargando = false);
  }

  Future<void> _guardar() async {
    final messenger = ScaffoldMessenger.of(context);
    final plazos = plazosCtrl.text
        .split(',')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .where((e) => e > 0)
        .toList();

    final data = {
      'tasa_interes_anual': double.tryParse(tasaCtrl.text) ?? 10,
      'porcentaje_multa': double.tryParse(multaCtrl.text) ?? 2,
      'limite_prestamo': double.tryParse(limiteCtrl.text) ?? 5000,
      'min_ahorro': double.tryParse(ahorroCtrl.text) ?? 10,
      'plazos_fijos': plazos,
      'ultima_actualizacion': DateTime.now(),
    };

    await configService.updateConfig(data);
    // Use captured messenger to avoid use_build_context_synchronously after await
    messenger.showSnackBar(
      const SnackBar(content: Text('Configuración actualizada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración Global')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            _buildCampo(tasaCtrl, 'Tasa de interés anual (%)'),
            _buildCampo(multaCtrl, 'Porcentaje de multa mensual (%)'),
            _buildCampo(limiteCtrl, 'Límite máximo de préstamo'),
            _buildCampo(ahorroCtrl, 'Monto mínimo de ahorro'),
            _buildCampo(plazosCtrl, 'Plazos fijos (separados por comas)'),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Guardar configuración'),
              onPressed: _guardar,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampo(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      ),
    );
  }
}
