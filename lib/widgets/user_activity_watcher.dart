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
  bool _isInBackground = false;

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
    // Nos suscribimos a los cambios de estado de la app para sólo comenzar
    // a contar la inactividad cuando la app se ponga en background.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App no visible -> iniciar temporizador de inactividad
      _isInBackground = true;
      _resetTimer();
    } else if (state == AppLifecycleState.resumed) {
      // App volvió al foreground -> cancelar temporizador
      _isInBackground = false;
      _timer?.cancel();
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
      // Mantener los handlers por robustez, pero ahora el temporizador
      // sólo se activa cuando la app está en background — estos handlers
      // son útiles si cambias la política en el futuro.
      onPointerDown: (_) => _isInBackground ? _resetTimer() : null,
      onPointerMove: (_) => _isInBackground ? _resetTimer() : null,
      onPointerUp: (_) => _isInBackground ? _resetTimer() : null,
      onPointerCancel: (_) => _isInBackground ? _resetTimer() : null,
      onPointerSignal: (_) => _isInBackground ? _resetTimer() : null,
      child: widget.child,
    );
  }
}
