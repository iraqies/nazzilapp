import 'dart:convert';
import 'dart:io';

import '../models/media.dart';
import 'link_parser.dart';

class NetClient {
  NetClient() {
    _client.userAgent = NetHints.mobileUa;
    _client.connectionTimeout = const Duration(seconds: 20);
    _client.idleTimeout = const Duration(seconds: 180);
  }

  final HttpClient _client = HttpClient();
  HttpClientRequest? _active;
  int _gen = 0;
  bool _pause = false;

  int get generation => _gen;

  void cancel() {
    _pause = false;
    _gen += 1;
    _abort();
  }

  void pause() {
    _pause = true;
    _gen += 1;
    _abort();
  }

  void _abort() {
    final active = _active;
    _active = null;
    try {
      active?.abort();
    } catch (_) {}
  }

  void _throwIfStopped(int gen) {
    if (gen == _gen) return;
    if (_pause) throw const PausedException();
    throw CancelledException();
  }

  Future<String> get(
    String url, {
    Map<String, String> headers = const {},
    String userAgent = NetHints.mobileUa,
  }) async {
    final response = await _open(url, headers: headers, userAgent: userAgent);
    return _readBody(response);
  }

  Future<String> post(
    String url,
    String body, {
    Map<String, String> headers = const {},
    String userAgent = NetHints.mobileUa,
    bool json = false,
  }) async {
    final response = await _open(
      url,
      headers: {
        'Content-Type': json
            ? 'application/json'
            : 'application/x-www-form-urlencoded; charset=UTF-8',
        ...headers,
      },
      userAgent: userAgent,
      body: body,
    );
    return _readBody(response);
  }

  Future<File> save(
    String url,
    File dest, {
    required String referer,
    String userAgent = NetHints.mobileUa,
    void Function(double progress)? onProgress,
  }) async {
    Object? last;
    for (var attempt = 0; attempt < 4; attempt++) {
      final gen = _gen;
      try {
        return await _saveOnce(
          url,
          dest,
          referer: referer,
          userAgent: userAgent,
          onProgress: onProgress,
          gen: gen,
        );
      } on PausedException {
        rethrow;
      } on CancelledException {
        rethrow;
      } catch (error) {
        last = error;
        if (!_transient(error) || attempt == 3) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw last ?? StateError('Download failed');
  }

  Future<File> _saveOnce(
    String url,
    File dest, {
    required String referer,
    required String userAgent,
    void Function(double progress)? onProgress,
    required int gen,
  }) async {
    _throwIfStopped(gen);
    final already = dest.existsSync() ? dest.lengthSync() : 0;
    if (already <= 0 && dest.existsSync()) dest.deleteSync();
    dest.parent.createSync(recursive: true);

    final headers = <String, String>{
      'Referer': referer,
      'Accept': '*/*',
      'Accept-Encoding': 'identity',
    };
    if (already > 0) headers['Range'] = 'bytes=$already-';

    late final HttpClientResponse response;
    try {
      response = await _open(url, headers: headers, userAgent: userAgent);
    } catch (error) {
      _throwIfStopped(gen);
      rethrow;
    }
    _throwIfStopped(gen);
    final code = response.statusCode;
    if (code == 416) {
      await response.drain<void>();
      if (dest.existsSync()) dest.deleteSync();
      throw const HttpException('Resume rejected');
    }
    if (code < 200 || code > 299 && code != 206) {
      await response.drain<void>();
      throw HttpException(_statusMessage(code), uri: Uri.parse(url));
    }
    final type = response.headers.contentType?.mimeType ?? '';
    if (type.startsWith('text/html') || type.startsWith('application/json')) {
      await response.drain<void>();
      throw const HttpException('This file blocked the download. Try again.');
    }
    final restart = already > 0 && code == 200;
    final chunk = response.contentLength;
    final total = code == 206 && chunk > 0 ? already + chunk : chunk;
    final sink = dest.openWrite(mode: restart || already <= 0 ? FileMode.write : FileMode.append);
    var read = restart ? 0 : already;
    var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      await for (final data in response) {
        _throwIfStopped(gen);
        sink.add(data);
        read += data.length;
        final now = DateTime.now();
        if (now.difference(lastEmit).inMilliseconds >= 120) {
          lastEmit = now;
          onProgress?.call(_progressOf(read, total));
        }
      }
      await sink.flush();
    } on PausedException {
      try {
        await sink.flush();
      } catch (_) {}
      rethrow;
    } on CancelledException {
      if (dest.existsSync()) dest.deleteSync();
      rethrow;
    } catch (error) {
      _throwIfStopped(gen);
      rethrow;
    } finally {
      try {
        await sink.close();
      } catch (_) {}
    }
    if (dest.lengthSync() < 800) {
      dest.deleteSync();
      throw const HttpException('Download was empty');
    }
    onProgress?.call(1);
    return dest;
  }

  Future<HttpClientResponse> _open(
    String url, {
    Map<String, String> headers = const {},
    String userAgent = NetHints.mobileUa,
    String? body,
  }) async {
    var current = Uri.parse(url);
    for (var hop = 0; hop < 8; hop++) {
      final postFirst = body != null && hop == 0;
      final request = postFirst
          ? await _client.postUrl(current)
          : await _client.getUrl(current);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      headers.forEach(request.headers.set);
      _active = request;
      if (postFirst) {
        request.add(utf8.encode(body));
      }
      final response = await request.close();
      _active = null;
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null || location.isEmpty) {
          throw const HttpException('Redirect without location');
        }
        current = current.resolve(location);
        continue;
      }
      return response;
    }
    throw const HttpException('Too many redirects');
  }

  Future<String> _readBody(HttpClientResponse response) async {
    final bytes = await response.fold<List<int>>(<int>[], (prev, chunk) {
      prev.addAll(chunk);
      return prev;
    });
    final text = utf8.decode(bytes, allowMalformed: true);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}', uri: response.redirects.isEmpty ? null : response.redirects.last.location);
    }
    return text;
  }

  double _progressOf(int read, int total) {
    if (total > 0) return (read / total).clamp(0.0, 0.99);
    final mb = read / (1024 * 1024);
    return (0.16 + (mb / (mb + 10)) * 0.72).clamp(0.16, 0.88);
  }

  bool _transient(Object error) {
    if (error is CancelledException || error is PausedException) return false;
    if (error is SocketException || error is HttpException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('timeout') ||
        text.contains('reset') ||
        text.contains('broken pipe') ||
        text.contains('connection');
  }

  String _statusMessage(int code) {
    return switch (code) {
      401 || 403 => 'This post blocked the download. Try again.',
      404 => 'This post is gone.',
      _ => 'Download failed ($code)',
    };
  }

  void close() => _client.close(force: true);
}

String decodeEscaped(String value) {
  return value
      .replaceAll(r'\u0026', '&')
      .replaceAll(r'\u003d', '=')
      .replaceAll(r'\/', '/')
      .replaceAll(r'\"', '"')
      .replaceAll('&amp;', '&');
}

String? firstGroup(String text, List<RegExp> patterns) {
  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    final value = match?.group(1);
    if (value != null && value.isNotEmpty) return decodeEscaped(value);
  }
  return null;
}

String? og(String html, String prop) {
  return firstGroup(html, [
    RegExp('property=["\']og:$prop["\'][^>]*content=["\']([^"\']+)', caseSensitive: false),
    RegExp('content=["\']([^"\']+)["\'][^>]*property=["\']og:$prop["\']', caseSensitive: false),
  ]);
}

List<String> uniqueUrls(Iterable<String?> urls) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in urls) {
    if (raw == null || raw.isEmpty) continue;
    final clean = decodeEscaped(raw.trim());
    if (!clean.startsWith('http') || seen.contains(clean)) continue;
    seen.add(clean);
    out.add(clean);
  }
  return out;
}
