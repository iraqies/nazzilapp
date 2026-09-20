import 'dart:convert';

import '../../models/media.dart';
import '../net.dart';

class CobaltClient {
  CobaltClient(this.net);
  final NetClient net;

  static const _hosts = [
    'https://api.cobalt.tools',
    'https://cobalt.api.timelessnesses.me',
    'https://co.eepy.today',
  ];

  Future<MediaInfo> fetch(String pageUrl, PlatformId platform) async {
    Object? last;
    for (final host in _hosts) {
      try {
        return await _request(host, pageUrl, platform);
      } catch (error) {
        last = error;
      }
    }
    throw last ?? StateError('Could not load this link');
  }

  Future<MediaInfo> _request(String host, String pageUrl, PlatformId platform) async {
    final raw = await net.post(
      '$host/',
      jsonEncode({
        'url': pageUrl,
        'videoQuality': '1080',
        'downloadMode': 'auto',
      }),
      json: true,
    );
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) throw StateError('No video');
    if (json['status'] == 'error' || json['error'] != null) {
      final message = (json['error'] is Map ? json['error']['code'] : json['text'])?.toString();
      throw StateError(message?.isNotEmpty == true ? message! : 'Lookup failed');
    }
    final url = json['url']?.toString() ?? '';
    if (!url.startsWith('http')) throw StateError('No video');
    final filename = json['filename']?.toString() ?? '';
    final title = filename.contains('.')
        ? filename.substring(0, filename.lastIndexOf('.'))
        : (filename.isEmpty ? '${platform.name} video' : filename);
    return MediaInfo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      thumbnail: (json['thumbnail'] as String?)?.isNotEmpty == true
          ? json['thumbnail'] as String
          : null,
      webpageUrl: pageUrl,
      platform: platform,
      options: [
        QualityOption(
          id: 'cobalt-hd',
          label: 'HD',
          ext: 'mp4',
          kind: MediaKind.video,
          directUrl: url,
        ),
        const QualityOption(
          id: 'cobalt-audio',
          label: 'Audio',
          ext: 'm4a',
          kind: MediaKind.audio,
        ),
      ],
    );
  }
}
