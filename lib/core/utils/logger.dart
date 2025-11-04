import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Logger simple centralizado para pruebas/depuración.
/// En producción se puede reemplazar por un paquete más avanzado.
class AppLogger {
  static void info(String message, [Map<String, Object?>? params]) {
    final msg = '[INFO] $message${_formatParams(params)}';
    developer.log(msg, name: 'AppLogger', level: 800);
    if (kDebugMode) print(msg);
  }

  static void warn(String message, [Map<String, Object?>? params]) {
    final msg = '[WARN] $message${_formatParams(params)}';
    developer.log(msg, name: 'AppLogger', level: 900);
    if (kDebugMode) print(msg);
  }

  static void error(String message, [Object? error, StackTrace? st]) {
    final msg = '[ERROR] $message';
    developer.log(msg, name: 'AppLogger', level: 1000, error: error, stackTrace: st);
    if (kDebugMode) {
      print(msg);
      if (error != null) print('Error: $error');
      if (st != null) print('Stack: $st');
    }
  }

  static String _formatParams(Map<String, Object?>? params) {
    if (params == null || params.isEmpty) return '';
    try {
      return ' | ' + params.entries.map((e) => '${e.key}=${e.value}').join(', ');
    } catch (_) {
      return '';
    }
  }
}
