import 'dart:convert';

import '../../models/media.dart';
import '../link_parser.dart';
import '../net.dart';

class TikTokClient {
  TikTokClient(this.net);
  final NetClient net;

  Future<MediaInfo> fetch(String pageUrl) async {
    Object? last;
    final attempts = LinkParser.isTikTokPhotoUrl(pageUrl) ||
            pageUrl.contains('vm.tiktok') ||
            pageUrl.contains('vt.tiktok')
        ? 4
        : 3;
    for (var i = 0; i < attempts; i++) {
      try {
        return parse(await _request(pageUrl), pageUrl);
      } catch (error) {
        last = error;
        if (error.toString().toLowerCase().contains('url parsing is failed')) break;
        final limit = error.toString().toLowerCase().contains('limit');
        await Future<void>.delayed(
          Duration(milliseconds: i == 0 ? 900 : limit ? 1500 : 600),
        );
      }
    }
    try {
      return await _fromHtml(pageUrl);
    } catch (error) {
      if (error is StateError && error.message == goneMessage) rethrow;
      throw last ?? error;
    }
  }

  Future<Map<String, dynamic>> _request(String pageUrl) async {
    final encoded = Uri.encodeQueryComponent(pageUrl);
    final endpoints = [
      'https://www.tikwm.com/api/?url=$encoded&hd=1',
      'https://tikwm.com/api/?url=$encoded&hd=1',
    ];
    Object? last;
    for (final endpoint in endpoints) {
      try {
        return _readJson(await net.get(endpoint, userAgent: NetHints.desktopUa));
      } catch (error) {
        last = error;
      }
    }
    try {
      return _readJson(
        await net.post(
          'https://www.tikwm.com/api/',
          'url=$encoded&hd=1',
          userAgent: NetHints.desktopUa,
        ),
      );
    } catch (error) {
      throw last ?? error;
    }
  }

  Map<String, dynamic> _readJson(String body) {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('TikTok lookup failed');
    }
    final code = json['code'];
    final ok = code == 0 || code == '0';
    if (!ok) {
      throw StateError((json['msg'] as String?)?.trim().isNotEmpty == true
          ? json['msg'] as String
          : 'TikTok lookup failed');
    }
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('TikTok returned no data');
    }
    return data;
  }

  MediaInfo parse(Map<String, dynamic> data, String pageUrl) {
    final photos = _photoUrls(data['images']);
    final hd = _abs(data['hdplay']?.toString());
    final play = _abs(data['play']?.toString());
    final music = _abs(data['music']?.toString());
    final author = data['author'];
    final nickname = author is Map
        ? (author['nickname'] ?? author['unique_id'])?.toString()
        : null;
    final id = (data['id']?.toString().isNotEmpty == true)
        ? data['id'].toString()
        : (LinkParser.tiktokId(pageUrl) ?? DateTime.now().millisecondsSinceEpoch.toString());
    final title = cleanTitle(
      data['title'] as String? ?? '',
      fallback: photos.isNotEmpty ? 'TikTok photos' : 'TikTok video',
    );

    final options = <QualityOption>[];
    if (photos.isNotEmpty) {
      options.add(
        QualityOption(
          id: 'tiktok-photos',
          label: 'Photos',
          ext: 'jpg',
          kind: MediaKind.photo,
          photoUrls: photos,
        ),
      );
    } else {
      if (hd != null) {
        options.add(QualityOption(
          id: 'tikwm-hd',
          label: 'HD',
          ext: 'mp4',
          kind: MediaKind.video,
          directUrl: hd,
        ));
      }
      if (play != null && play != hd) {
        options.add(QualityOption(
          id: 'tikwm-sd',
          label: 'SD',
          ext: 'mp4',
          kind: MediaKind.video,
          directUrl: play,
        ));
      }
    }
    if (music != null) {
      options.add(QualityOption(
        id: 'tikwm-audio',
        label: 'Audio',
        ext: 'mp3',
        kind: MediaKind.audio,
        directUrl: music,
      ));
    }
    if (options.isEmpty) {
      throw StateError('Could not read this TikTok post');
    }

    return MediaInfo(
      id: id,
      title: title,
      author: nickname,
      thumbnail: _abs(data['cover']?.toString()) ??
          _abs(data['origin_cover']?.toString()) ??
          (photos.isNotEmpty ? photos.first : null),
      duration: (data['duration'] as num?)?.toInt(),
      webpageUrl: pageUrl,
      platform: PlatformId.tiktok,
      options: options,
      photos: photos,
    );
  }

  Future<MediaInfo> _fromHtml(String pageUrl) async {
    final resolved = await LinkParser.resolve(pageUrl);
    final postId = LinkParser.tiktokId(resolved);
    // Dead or private links land on the home page, whose feed would otherwise
    // be read as this post.
    if (postId == null) throw StateError(goneMessage);
    final html = await net.get(resolved, userAgent: NetHints.desktopUa);
    if (!pageIsPost(html, postId)) throw StateError(goneMessage);
    final photos = _photosFromHtml(html);
    final play = firstGroup(html, [
      RegExp(r'"playAddr"\s*:\s*"([^"]+)"'),
      RegExp(r'"play_addr"\s*:\s*"([^"]+)"'),
    ]);
    final download = firstGroup(html, [
      RegExp(r'"downloadAddr"\s*:\s*"([^"]+)"'),
      RegExp(r'"download_addr"\s*:\s*"([^"]+)"'),
    ]);
    final title = og(html, 'title') ?? 'TikTok';
    final cover = og(html, 'image');
    final id = postId;
    final options = <QualityOption>[];
    if (photos.isNotEmpty) {
      options.add(QualityOption(
        id: 'tiktok-photos',
        label: 'Photos',
        ext: 'jpg',
        kind: MediaKind.photo,
        photoUrls: photos,
      ));
    } else if (download != null || play != null) {
      options.add(QualityOption(
        id: 'tiktok-video',
        label: 'HD',
        ext: 'mp4',
        kind: MediaKind.video,
        directUrl: decodeEscaped(download ?? play!),
      ));
    }
    if (options.isEmpty) {
      throw StateError('Could not read this TikTok post. Make sure it is public.');
    }
    return MediaInfo(
      id: id,
      title: title,
      thumbnail: cover ?? (photos.isNotEmpty ? photos.first : null),
      webpageUrl: resolved,
      platform: PlatformId.tiktok,
      options: options,
      photos: photos,
    );
  }

  static const goneMessage = 'This TikTok post is gone or private.';

  static bool pageIsPost(String html, String postId) {
    return RegExp('"(?:id|itemId|aweme_id)"\\s*:\\s*"$postId"').hasMatch(html);
  }

  List<String> _photoUrls(dynamic raw) {
    if (raw is! List) return const [];
    final out = <String>[];
    for (final item in raw) {
      if (item is String) {
        final url = _abs(item);
        if (url != null && _looksLikeImage(url)) out.add(url);
      } else if (item is Map) {
        final url = _abs(
          (item['url'] ??
                  item['image'] ??
                  item['display_image'] ??
                  (item['imageURL'] is Map ? (item['imageURL'] as Map)['urlList'] : null))
              ?.toString(),
        );
        if (url != null && _looksLikeImage(url)) {
          out.add(url);
        } else if (item['imageURL'] is Map) {
          final list = (item['imageURL'] as Map)['urlList'];
          if (list is List) {
            for (final u in list) {
              final abs = _abs(u.toString());
              if (abs != null && _looksLikeImage(abs)) {
                out.add(abs);
                break;
              }
            }
          }
        }
      }
    }
    return uniqueUrls(out);
  }

  List<String> _photosFromHtml(String html) {
    final unescaped = decodeEscaped(html);
    final fromBlock = <String>[];
    final block = RegExp(
      r'"imagePost"\s*:\s*\{.*?"images"\s*:\s*\[(.*?)\]',
      dotAll: true,
    ).firstMatch(unescaped);
    if (block != null) {
      fromBlock.addAll(
        RegExp(r'https://[^"\\]+').allMatches(block.group(1)!).map((m) => m.group(0)!),
      );
    }
    fromBlock.addAll(
      RegExp(
        r'"urlList"\s*:\s*\[\s*"(https://[^"]+)"',
      ).allMatches(unescaped).map((m) => m.group(1)!),
    );
    return uniqueUrls(fromBlock.where(_looksLikeImage));
  }

  bool _looksLikeImage(String url) {
    final value = url.toLowerCase();
    if (!value.startsWith('http')) return false;
    if (value.contains('.mp4') || value.contains('/video/')) return false;
    return value.contains('.jpeg') ||
        value.contains('.jpg') ||
        value.contains('.png') ||
        value.contains('.webp') ||
        value.contains('.heic') ||
        value.contains('image') ||
        value.contains('/photo');
  }

  String? _abs(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty || value == 'null') return null;
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('/')) return 'https://www.tikwm.com$value';
    if (value.startsWith('http')) return value;
    return null;
  }
}
