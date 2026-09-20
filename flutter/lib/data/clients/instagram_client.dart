import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/media.dart';
import '../link_parser.dart';
import '../net.dart';

class InstagramClient {
  InstagramClient(this.net);
  final NetClient net;

  static const _appId = '936619743392459';

  Future<MediaInfo> fetch(String pageUrl) async {
    final resolved = await LinkParser.resolve(pageUrl);
    final code = LinkParser.instagramCode(resolved);
    if (code == null) throw StateError('Could not read this Instagram link');
    final canonical = 'https://www.instagram.com/p/$code/';
    Object? last;
    for (final attempt in <Future<MediaInfo> Function()>[
      () => _fromOfficial(code, canonical),
      () => _fromEmbed(code, canonical),
      () => _fromSaveIg(canonical, code),
    ]) {
      try {
        return await attempt();
      } catch (error) {
        last = error;
      }
    }
    throw last ?? StateError('Could not load this Instagram link');
  }

  Future<MediaInfo> _fromOfficial(String code, String pageUrl) async {
    for (final ua in [NetHints.facebookUa, NetHints.botUa, NetHints.desktopUa]) {
      for (final kind in ['p', 'reel']) {
        try {
          final html = await net.get(
            'https://www.instagram.com/$kind/$code/',
            headers: {'Accept': 'text/html', 'X-IG-App-ID': _appId},
            userAgent: ua,
          );
          final videos = _mp4s(html);
          final photos = uniqueUrls([..._sidecar(html), ..._images(html)]);
          if (videos.isEmpty && photos.isEmpty) continue;
          return _meta(
            code,
            pageUrl,
            videos: videos,
            photos: photos,
            title: og(html, 'title'),
            thumb: og(html, 'image'),
          );
        } catch (_) {}
      }
    }
    throw StateError('Instagram page had no media');
  }

  Future<MediaInfo> _fromEmbed(String code, String pageUrl) async {
    final html = await net.get(
      'https://www.instagram.com/p/$code/embed/captioned/',
      userAgent: NetHints.desktopUa,
    );
    final videos = _mp4s(html);
    final photos = uniqueUrls([..._sidecar(html), ..._images(html)]);
    if (videos.isEmpty && photos.isEmpty) {
      throw StateError('Instagram embed had no media');
    }
    return _meta(
      code,
      pageUrl,
      videos: videos,
      photos: photos,
      title: og(html, 'title'),
      thumb: og(html, 'image'),
    );
  }

  Future<MediaInfo> _fromSaveIg(String pageUrl, String code) async {
    final encoded = Uri.encodeQueryComponent(pageUrl);
    final body = await net.post(
      'https://saveig.app/api/ajaxSearch',
      'q=$encoded&t=media&lang=en',
      headers: {
        'Origin': 'https://saveig.app',
        'Referer': 'https://saveig.app/en/instagram-video-downloader',
        'X-Requested-With': 'XMLHttpRequest',
      },
    );
    String html = body;
    try {
      final json = jsonDecode(body);
      if (json is Map && json['data'] is String) html = json['data'] as String;
    } catch (_) {}
    final videos = uniqueUrls(
      RegExp(r'''href=["'](https?://[^"']+)["']''', caseSensitive: false)
          .allMatches(html)
          .map((m) => m.group(1))
          .where((u) => u != null && u.toLowerCase().contains('.mp4')),
    );
    final photos = _images(html);
    if (videos.isEmpty && photos.isEmpty) {
      throw StateError('SaveIG had no media');
    }
    return _meta(code, pageUrl, videos: videos, photos: photos, title: null, thumb: og(html, 'image'));
  }

  MediaInfo _meta(
    String id,
    String pageUrl, {
    required List<String> videos,
    required List<String> photos,
    String? title,
    String? thumb,
  }) {
    final options = <QualityOption>[];
    final album = photos.length > 1;
    if (album || (photos.isNotEmpty && videos.isEmpty)) {
      options.add(QualityOption(
        id: 'ig-photos',
        label: 'Photos',
        ext: 'jpg',
        kind: MediaKind.photo,
        photoUrls: photos,
      ));
    }
    if (videos.isNotEmpty && !album) {
      options.add(QualityOption(
        id: 'ig-hd',
        label: 'HD',
        ext: 'mp4',
        kind: MediaKind.video,
        directUrl: videos.first,
      ));
      if (videos.length > 1 && videos.last != videos.first) {
        options.add(QualityOption(
          id: 'ig-sd',
          label: 'SD',
          ext: 'mp4',
          kind: MediaKind.video,
          directUrl: videos.last,
        ));
      }
      options.add(QualityOption(
        id: 'ig-audio',
        label: 'Audio',
        ext: 'm4a',
        kind: MediaKind.audio,
        directUrl: videos.first,
      ));
    }
    final parsed = _instagramTitle(title);
    return MediaInfo(
      id: id,
      title: parsed.$1,
      author: parsed.$2,
      thumbnail: thumb ?? (photos.isNotEmpty ? photos.first : null),
      webpageUrl: pageUrl,
      platform: PlatformId.instagram,
      options: options,
      photos: album || videos.isEmpty ? photos : const [],
    );
  }

  List<String> _mp4s(String html) {
    final unescaped = decodeEscaped(html);
    return uniqueUrls(
      RegExp(r'https://[^\s"<>\\]+?\.mp4[^\s"<>\\]*')
          .allMatches(unescaped)
          .map((m) => m.group(0))
          .where((u) =>
              u != null &&
              (u.contains('cdninstagram') || u.contains('fbcdn') || u.contains('.mp4'))),
    );
  }

  List<String> _images(String html) {
    final unescaped = decodeEscaped(html);
    return uniqueUrls(
      [
        og(unescaped, 'image'),
        ...RegExp(r'https://[^\s"<>\\]+?(?:scontent|cdninstagram)[^\s"<>\\]+')
            .allMatches(unescaped)
            .map((m) => m.group(0)),
      ].where((u) {
        if (u == null) return false;
        final v = u.toLowerCase();
        return !v.contains('.mp4') && _looksLikePostImage(v);
      }),
    ).take(30).toList();
  }

  List<String> _sidecar(String html) {
    final unescaped = decodeEscaped(html);
    return uniqueUrls(
      [
        ...RegExp(r'"display_url"\s*:\s*"(https:[^"]+)"').allMatches(unescaped).map((m) => m.group(1)),
        ...RegExp(r'"display_src"\s*:\s*"(https:[^"]+)"').allMatches(unescaped).map((m) => m.group(1)),
        ...RegExp(r'"carousel_media"\s*:\s*\[(.*?)\]', dotAll: true).allMatches(unescaped).expand(
              (m) => RegExp(r'https://[^"\\]+').allMatches(m.group(1)!).map((u) => u.group(0)),
            ),
        ...RegExp(r'"edge_sidecar_to_children".{0,8000}?"display_url":"(https:[^"]+)"', dotAll: true)
            .allMatches(unescaped)
            .map((m) => m.group(1)),
      ].where((u) {
        if (u == null) return false;
        final v = decodeEscaped(u).toLowerCase();
        return !v.contains('.mp4') && _looksLikePostImage(v);
      }),
    );
  }

  bool _looksLikePostImage(String url) {
    if (url.contains('s150x150') ||
        url.contains('s320x320') ||
        url.contains('s50x50') ||
        url.contains('/profile') ||
        url.contains('profile_pic')) {
      return false;
    }
    return url.contains('scontent') ||
        url.contains('cdninstagram') ||
        url.contains('.jpg') ||
        url.contains('.jpeg') ||
        url.contains('.webp') ||
        url.contains('.png');
  }

  (String, String?) _instagramTitle(String? raw) {
    var text = (raw ?? '')
        .replaceAll(RegExp(r'\s*[•·]\s*Instagram.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(@[A-Za-z0-9._]+\)\s*'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final author = RegExp(r'@([A-Za-z0-9._]+)').firstMatch(raw ?? '')?.group(1);
    if (text.isEmpty) text = 'Instagram';
    return (text, author);
  }

  @visibleForTesting
  MediaInfo metaFrom({
    required List<String> videos,
    required List<String> photos,
    String? title,
    String? thumb,
  }) {
    return _meta(
      'testid',
      'https://www.instagram.com/p/testid/',
      videos: videos,
      photos: photos,
      title: title,
      thumb: thumb,
    );
  }
}
