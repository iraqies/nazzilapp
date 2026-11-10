import 'package:flutter/services.dart';

import 'platforms.dart';

class InboundShare {
  static const _events = EventChannel('nazzil/share');
  static const _methods = MethodChannel('nazzil/share/methods');

  static Future<String?> initial() async {
    if (!Platforms.mobile) return null;
    try {
      return await _methods.invokeMethod<String>('initial');
    } catch (_) {
      return null;
    }
  }

  static Stream<String> stream() {
    if (!Platforms.mobile) return const Stream.empty();
    return _events.receiveBroadcastStream().map((event) => event.toString());
  }
}
