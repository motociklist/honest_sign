import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Логи отладки КМ.
/// - [developer.log]: IDE / DevTools (имя `qrcode_km`).
/// - [debugPrint]: видно в консоли браузера при **flutter run -d chrome** (F12 → Console).
void kmLog(String message, {Object? error, StackTrace? stackTrace}) {
  final line = '[qrcode_km] $message';
  developer.log(
    message,
    name: 'qrcode_km',
    error: error,
    stackTrace: stackTrace,
  );
  if (kIsWeb) {
    // ignore: avoid_print
    print(line);
    if (error != null) {
      // ignore: avoid_print
      print('[qrcode_km] error: $error');
    }
    if (stackTrace != null && kDebugMode) {
      // ignore: avoid_print
      print(stackTrace);
    }
  } else {
    debugPrint(line);
    if (error != null) {
      debugPrint('[qrcode_km] error: $error');
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint(stackTrace.toString());
    }
  }
}
