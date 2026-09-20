import 'package:flutter/services.dart';

class InboundShare {
  static const _events = EventChannel('nazzil/share');
  static const _methods = MethodChannel('nazzil/share/methods');

  static Future<String?> initial() async {
    try {
      return await _methods.invokeMethod<String>('initial');
    } catch (_) {
      return null;
    }
  }

  static Stream<String> stream() {
    return _events.receiveBroadcastStream().map((event) => event.toString());
  }
}
