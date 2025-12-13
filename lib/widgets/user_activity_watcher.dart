import 'dart:async';

import 'package:flutter/material.dart';
import '/core/services/auth_service.dart';

/// Widget que envuelve la aplicación y detecta actividad del usuario (toques,
/// desplazamientos). Si no hay actividad por [timeout], ejecuta [onTimeout].
class UserActivityWatcher extends StatefulWidget {
  final Widget child;
  final Duration timeout;
  final GlobalKey<NavigatorState>? navigatorKey;

  const UserActivityWatcher({
    super.key,
    required this.child,
    // Por defecto 2 minutos de inactividad antes de cerrar sesión.
    // Nota: la lógica ahora sólo inicia el temporizador cuando la app
    // pasa a background (AppLifecycleState.paused). Esto evita que la
    // sesión se cierre mientras el usuario está interactuando en foreground.
    this.timeout = const Duration(minutes: 2),
    this.navigatorKey,
  });

  @override
  State<UserActivityWatcher> createState() => _UserActivityWatcherState();
}

class _UserActivityWatcherState extends State<UserActivityWatcher>
    with WidgetsBindingObserver {
  Timer? _timer;
  final _auth = AuthService();

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, _onTimeout);
  }

  void _onTimeout() async {
    // Cerrar sesión
    // Capture navigator before awaiting to avoid using BuildContext after await
    final nav = widget.navigatorKey?.currentState ?? Navigator.of(context);
    await _auth.logout();
    // Navegar a login
    nav.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  void initState() {
    super.initState();
    // Suscribirse a los cambios de estado de la app y arrancar el timer de
    // inmediato para capturar inactividad en foreground y background.
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      // La app se cerró o fue destruida por el SO: cerrar sesión al instante.
      _onTimeout();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App no visible -> arrancar timer de logout.
      _resetTimer();
    } else if (state == AppLifecycleState.resumed) {
      // App volvió al foreground -> reiniciar timer para 2 min de inactividad.
      _resetTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      // Cada interacción reinicia el temporizador de inactividad en
      // foreground y background para garantizar el cierre tras 2 minutos.
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerUp: (_) => _resetTimer(),
      onPointerCancel: (_) => _resetTimer(),
      onPointerSignal: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
