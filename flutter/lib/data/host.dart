import 'package:flutter/services.dart';

class DownloadHost {
  static const _ch = MethodChannel('nazzil/host');

  static void bind({
    required void Function(bool library) onOpened,
    required Future<void> Function() onPause,
    required Future<void> Function() onResume,
    required Future<void> Function() onCancel,
  }) {
    _ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'opened':
          final args = call.arguments;
          final library = args == true ||
              (args is Map && (args['library'] == true || args['library'] == 'true'));
          onOpened(library);
        case 'pause':
          await onPause();
        case 'resume':
          await onResume();
        case 'cancel':
          await onCancel();
      }
    });
    () async {
      try {
        final pending = await _ch.invokeMethod<dynamic>('drain');
        if (pending is Map) {
          if (pending['library'] == true) onOpened(true);
          if (pending['resume'] == true) await onResume();
          if (pending['cancel'] == true) await onCancel();
        }
      } catch (_) {}
    }();
  }

  static Future<void> start({String title = 'Nazzil', int percent = 1}) async {
    try {
      await _ch.invokeMethod<void>('start', {'title': title, 'percent': percent});
    } catch (_) {}
  }

  static Future<void> progress(String title, int percent) async {
    try {
      await _ch.invokeMethod<void>('progress', {'title': title, 'percent': percent});
    } catch (_) {}
  }

  static Future<void> paused(String title, int percent) async {
    try {
      await _ch.invokeMethod<void>('paused', {'title': title, 'percent': percent});
    } catch (_) {}
  }

  static Future<void> done(String title, {String? path}) async {
    try {
      await _ch.invokeMethod<void>('done', {'title': title, 'path': path});
    } catch (_) {}
  }

  static Future<void> failed(String message) async {
    try {
      await _ch.invokeMethod<void>('failed', {'message': message});
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _ch.invokeMethod<void>('stop');
    } catch (_) {}
  }

  static Future<void> openFile(String path) async {
    await _ch.invokeMethod<void>('openFile', {'path': path});
  }

  static Future<String?> tagAudio({
    required String path,
    required String title,
    String? author,
    String? coverPath,
    String? lyricsPlain,
    String? lyricsSynced,
  }) async {
    try {
      return await _ch.invokeMethod<String>('tagAudio', {
        'path': path,
        'title': title,
        'author': author,
        'coverPath': coverPath,
        'lyricsPlain': lyricsPlain,
        'lyricsSynced': lyricsSynced,
      });
    } catch (_) {
      return null;
    }
  }
}
