import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'id3.dart';
import 'platforms.dart';

class DownloadHost {
  static const _ch = MethodChannel('nazzil/host');

  static void bind({
    required void Function(bool library) onOpened,
    required Future<void> Function() onPause,
    required Future<void> Function() onResume,
    required Future<void> Function() onCancel,
  }) {
    if (!Platforms.mobile) return;
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

  static Future<void> _notify(String method, [Map<String, Object?>? args]) async {
    if (!Platforms.mobile) return;
    try {
      await _ch.invokeMethod<void>(method, args);
    } catch (_) {}
  }

  static Future<void> start({String title = 'Nazzil', int percent = 1}) =>
      _notify('start', {'title': title, 'percent': percent});

  static Future<void> progress(String title, int percent) => _notify('progress', {'title': title, 'percent': percent});

  static Future<void> paused(String title, int percent) => _notify('paused', {'title': title, 'percent': percent});

  static Future<void> done(String title, {String? path}) => _notify('done', {'title': title, 'path': path});

  static Future<void> failed(String message) => _notify('failed', {'message': message});

  static Future<void> stop() => _notify('stop');

  /// False when the system had nothing to open the file with.
  static Future<bool> openFile(String path) async {
    try {
      if (Platforms.mobile) {
        await _ch.invokeMethod<void>('openFile', {'path': path});
        return true;
      }
      final file = Uri.file(path);
      // GTK reports a launch as started even with no app for the file, so Linux asks first.
      if (Platform.isLinux && !await canLaunchUrl(file)) return false;
      return await launchUrl(file);
    } catch (_) {
      return false;
    }
  }

  static Future<String?> saveAudio(String path) {
    return _ch.invokeMethod<String>('saveAudio', {'path': path});
  }

  static Future<String?> tagAudio({
    required String path,
    required String title,
    String? author,
    String? coverPath,
    String? lyricsPlain,
    String? lyricsSynced,
  }) async {
    if (!Platforms.mobile) {
      return _tagInDart(path, title, author, coverPath, lyricsPlain, lyricsSynced);
    }
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

  /// Desktop songs are always MP3 (FFmpeg converts them), so ID3 is enough.
  static Future<String?> _tagInDart(
    String path,
    String title,
    String? author,
    String? coverPath,
    String? lyricsPlain,
    String? lyricsSynced,
  ) async {
    try {
      final file = File(path);
      if (!path.toLowerCase().endsWith('.mp3') || !file.existsSync()) return path;
      List<int>? jpeg;
      if (coverPath != null && File(coverPath).existsSync()) {
        final raw = await File(coverPath).readAsBytes();
        if (raw.length > 400 && raw[0] == 0xFF && raw[1] == 0xD8) jpeg = raw;
      }
      Id3Tag(
        title: title,
        artist: author,
        jpeg: jpeg,
        plainLyrics: lyricsPlain,
        syncedLyrics: lyricsSynced,
      ).writeTo(file);
      return path;
    } catch (_) {
      return path;
    }
  }
}
