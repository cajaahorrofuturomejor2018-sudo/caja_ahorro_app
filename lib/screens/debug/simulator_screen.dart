import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/firestore_service.dart';

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  final List<String> _logs = [];
  bool _running = false;
  final _service = FirestoreService();

  void _log(String s) {
    setState(() => _logs.insert(0, '${DateTime.now().toIso8601String()} - $s'));
  }

  Future<void> _runSimulation() async {
    if (_running) return;
    setState(() => _running = true);
    _logs.clear();
    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'sim_admin';
      _log('Inicio simulación (adminUid=$adminUid)');

      // 1) Crear usuario de prueba
      final testUid = 'sim_user_1';
      await _service.updateUsuario(testUid, {
        'nombres': 'Sim Usuario',
        'correo': 'sim@local.test',
        'rol': 'cliente',
        'total_ahorros': 0.0,
        'total_prestamos': 0.0,
        'total_multas': 0.0,
      });
      _log('Usuario de prueba creado/actualizado: $testUid');

      // 2) Crear solicitud de préstamo
      final prestamoPayload = {
        'id_usuario': testUid,
        'monto_solicitado': 600.0,
        'interes': 12.0,
        'plazo_meses': 6,
        'tipo': 'consumo',
        'fecha_registro': DateTime.now(),
      };
      final prestamoId = await _service.requestPrestamo(prestamoPayload);
      _log('Prestamo solicitado: $prestamoId');

      // 3) Aprobar préstamo
      await _service.approvePrestamo(
        prestamoId,
        adminUid,
        approve: true,
        montoAprobado: 600.0,
        interes: 12.0,
        plazoMeses: 6,
      );
      _log('Prestamo aprobado y activado: $prestamoId');

      // Leer préstamo aprobado
      final lista = await _service.getPrestamosOnce(testUid);
      final p = lista.firstWhere((x) => x.id == prestamoId);
      _log('Cuota mensual calculada: ${p.cuotaMensual}');

      // 4) Simular pagos mensuales hasta cancelar
      var iter = 0;
      while (p.estado != 'cancelado' && iter < 20) {
        final cuota = p.cuotaMensual ?? 0.0;
        final pago = {
          'monto': cuota,
          'fecha': DateTime.now(),
          'descripcion': 'Pago simulado #$iter',
          'registrado_por': adminUid,
        };
        await _service.addPagoPrestamo(prestamoId, pago);
        _log('Pago simulado registrado: ${cuota.toStringAsFixed(2)}');
        // leer estado actualizado
        final updated = (await _service.getPrestamoById(prestamoId));
        _log(
          'Estado ahora: ${updated?['estado']} - saldo: ${updated?['saldo_pendiente']} - meses: ${updated?['meses_restantes']}',
        );
        if (updated?['estado'] == 'cancelado') break;
        iter++;
      }

      // 5) Probar flujo de depósitos con vouchers
      // crear depósito con voucher hash
      final depRefId = await _service.createDeposito({
        'id_usuario': testUid,
        'tipo': 'efectivo',
        'monto': 150.0,
        'descripcion': 'Depósito simulado',
        'detalle_por_usuario': [],
        'archivo_url': '',
        'voucher_hash': 'sim_hash_123',
        'fecha_registro': DateTime.now(),
        'fecha_deposito': DateTime.now(),
      });
      _log('Depósito simulado creado: $depRefId');

      // aprobar depósito (primero ok)
      await _service.approveDeposito(depRefId, adminUid, approve: true);
      _log('Depósito aprobado: $depRefId');

      // crear depósito duplicado con mismo hash y probar bloqueo
      final dep2 = await _service.createDeposito({
        'id_usuario': testUid,
        'tipo': 'efectivo',
        'monto': 150.0,
        'descripcion': 'Depósito duplicado',
        'detalle_por_usuario': [],
        'archivo_url': '',
        'voucher_hash': 'sim_hash_123',
        'fecha_registro': DateTime.now(),
        'fecha_deposito': DateTime.now(),
      });
      _log('Depósito duplicado creado: $dep2');
      try {
        await _service.approveDeposito(dep2, adminUid, approve: true);
        _log('Dep duplicado aprobado (no detectado)');
      } catch (e) {
        _log('Duplicado detectado al aprobar: ${e.toString()}');
      }

      _log('Simulación completada');
    } catch (e, st) {
      _log('Error simulación: ${e.toString()}');
      _log(st.toString());
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simulador de pruebas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _running ? null : _runSimulation,
                  child: Text(
                    _running ? 'Ejecutando...' : 'Ejecutar simulación',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nota: la simulación ejecuta cambios en Firestore usando las reglas actuales. Recomendado usar Emulator para pruebas seguras.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (ctx, i) => ListTile(
                dense: true,
                title: Text(_logs[i], style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
