import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class RemoteVersion {
  const RemoteVersion({required this.version, required this.apkUrl, this.bytes = -1});
  final String version;
  final String apkUrl;
  final int bytes;
}

class UpdateChecker {
  static const site = 'https://iraqies.github.io/Nazzil/';
  static const manifest = '${site}versions.json';

  Future<String> current() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<RemoteVersion> fetch() async {
    final response = await http.get(Uri.parse(manifest));
    if (response.statusCode != 200) {
      throw StateError('Could not check for updates');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final releases = json['releases'] as List? ?? const [];
    final latest = (json['latest'] as String?)?.isNotEmpty == true
        ? json['latest'] as String
        : (releases.isNotEmpty ? (releases.first as Map)['version'] as String? : null);
    if (latest == null || latest.isEmpty) throw StateError('No version on the site');
    Map<String, dynamic>? match;
    for (final item in releases.whereType<Map>()) {
      if (item['version'] == latest) {
        match = Map<String, dynamic>.from(item);
        break;
      }
    }
    match ??= releases.isNotEmpty ? Map<String, dynamic>.from(releases.first as Map) : null;
    final apk = match?['apk']?.toString() ?? '';
    if (apk.isEmpty) throw StateError('No version on the site');
    final url = apk.startsWith('http') ? apk : Uri.parse(site).resolve(apk).toString();
    return RemoteVersion(
      version: latest,
      apkUrl: url,
      bytes: (match?['bytes'] as num?)?.toInt() ?? -1,
    );
  }

  bool isNewer(String remote, String local) => _compare(remote, local) > 0;

  Future<File> download(
    RemoteVersion remote, {
    void Function(int read, int total)? onBytes,
  }) async {
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'updates'));
    await dir.create(recursive: true);
    final dest = File(p.join(dir.path, 'nazzil-${remote.version}.apk'));
    final response = await http.Client().send(http.Request('GET', Uri.parse(remote.apkUrl)));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Update download failed');
    }
    final total = response.contentLength ?? remote.bytes;
    var read = 0;
    final sink = dest.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      read += chunk.length;
      onBytes?.call(read, total);
    }
    await sink.close();
    return dest;
  }

  int _compare(String left, String right) {
    final a = _parts(left);
    final b = _parts(right);
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  List<int> _parts(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^v'), '')
        .split(RegExp(r'[.\-\s]'))
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'\D'), '')) ?? 0)
        .toList();
  }
}
