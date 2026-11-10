import 'dart:convert';

import '../../models/media.dart';
import '../link_parser.dart';
import '../net.dart';

class InstagramClient {
  InstagramClient(this.net);
  final NetClient net;

  static const _pageHeaders = {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Site': 'none',
    'Upgrade-Insecure-Requests': '1',
  };

  Future<MediaInfo> fetch(String pageUrl) async {
    final resolved = await LinkParser.resolve(pageUrl);
    final code = LinkParser.instagramCode(resolved);
    if (code == null) throw StateError('Could not read this Instagram link');
    final canonical = 'https://www.instagram.com/p/$code/';
    Object? last;
    for (final attempt in <Future<MediaInfo> Function()>[
      () => _fromPage(code, canonical),
      () => _fromEmbed(code, canonical),
    ]) {
      try {
        return await attempt();
      } on CancelledException {
        rethrow;
      } catch (error) {
        last = error;
      }
    }
    throw last ?? StateError('Could not load this Instagram link');
  }

  Future<MediaInfo> _fromPage(String code, String pageUrl) async {
    final html = await net.get(
      'https://www.instagram.com/p/$code/',
      headers: _pageHeaders,
      userAgent: NetHints.desktopUa,
    );
    final product = productFromHtml(html);
    if (product == null) {
      throw StateError('Instagram did not share this post. It may be private, or Instagram wants a login right now.');
    }
    return fromProduct(product, code: code, pageUrl: pageUrl);
  }

  Future<MediaInfo> _fromEmbed(String code, String pageUrl) async {
    final html = await net.get(
      'https://www.instagram.com/p/$code/embed/captioned/',
      headers: {..._pageHeaders, 'Sec-Fetch-Dest': 'iframe'},
      userAgent: NetHints.desktopUa,
    );
    final node = shortcodeMediaFromEmbed(html);
    if (node == null) throw StateError('Instagram embed had no media');
    return fromShortcodeMedia(node, code: code, pageUrl: pageUrl);
  }

  /// The logged-out post page carries the post as Relay JSON inside
  /// `<script data-sjs>` blocks, under `xig_polaris_media`.
  static Map<String, dynamic>? productFromHtml(String html) {
    final scripts = RegExp(r'<script\b[^>]*\bdata-sjs\b[^>]*>(\{.+?\})</script>');
    for (final match in scripts.allMatches(html)) {
      final raw = match.group(1)!;
      if (!raw.contains('xig_polaris_media')) continue;
      Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        continue;
      }
      final media = _findKey(decoded, 'xig_polaris_media');
      if (media is! Map) continue;
      var product = media['if_not_gated_logged_out'];
      if (product is List && product.isNotEmpty) product = product.first;
      if (product is Map) return Map<String, dynamic>.from(product);
    }
    return null;
  }

  static Map<String, dynamic>? shortcodeMediaFromEmbed(String html) {
    final match = RegExp(r'"contextJSON":"((?:[^"\\]|\\.)*)"').firstMatch(html);
    if (match == null) return null;
    try {
      final context = jsonDecode(jsonDecode('"${match.group(1)}"') as String);
      final node = _findKey(context, 'shortcode_media');
      return node is Map ? Map<String, dynamic>.from(node) : null;
    } catch (_) {
      return null;
    }
  }

  static Object? _findKey(Object? value, String key) {
    if (value is Map) {
      if (value.containsKey(key) && value[key] != null) return value[key];
      for (final child in value.values) {
        final found = _findKey(child, key);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _findKey(child, key);
        if (found != null) return found;
      }
    }
    return null;
  }

  static MediaInfo fromProduct(
    Map<String, dynamic> product, {
    required String code,
    required String pageUrl,
  }) {
    final user = product['user'] is Map ? product['user'] as Map : const {};
    final username = user['username']?.toString();
    final caption = product['caption'] is Map ? (product['caption'] as Map)['text']?.toString() : null;
    final carousel = (product['carousel_media'] as List?)?.whereType<Map>().toList() ?? const [];
    final items = <_Item?>[
      if (carousel.isNotEmpty)
        for (final entry in carousel) _itemFromProduct(entry)
      else
        _itemFromProduct(product),
    ].whereType<_Item>().toList();
    final duration = (product['video_duration'] as num?)?.round();
    return _build(
      code: code,
      pageUrl: pageUrl,
      items: items,
      caption: caption,
      username: username,
      duration: duration,
    );
  }

  static MediaInfo fromShortcodeMedia(
    Map<String, dynamic> node, {
    required String code,
    required String pageUrl,
  }) {
    final children = ((node['edge_sidecar_to_children'] as Map?)?['edges'] as List?)
            ?.whereType<Map>()
            .map((edge) => edge['node'])
            .whereType<Map>()
            .toList() ??
        const [];
    final items = <_Item?>[
      if (children.isNotEmpty)
        for (final child in children) _itemFromNode(child)
      else
        _itemFromNode(node),
    ].whereType<_Item>().toList();
    final captionEdges = ((node['edge_media_to_caption'] as Map?)?['edges'] as List?) ?? const [];
    final caption = captionEdges.isEmpty ? null : ((captionEdges.first as Map?)?['node'] as Map?)?['text']?.toString();
    final owner = node['owner'] is Map ? node['owner'] as Map : const {};
    return _build(
      code: code,
      pageUrl: pageUrl,
      items: items,
      caption: caption,
      username: owner['username']?.toString(),
      duration: (node['video_duration'] as num?)?.round(),
    );
  }

  static _Item? _itemFromProduct(Map entry) {
    final candidates = ((entry['image_versions2'] as Map?)?['candidates'] as List?)?.whereType<Map>().toList() ?? <Map>[];
    candidates.sort((a, b) => ((b['width'] as num?) ?? 0).compareTo((a['width'] as num?) ?? 0));
    final image = candidates.isEmpty ? null : candidates.first['url']?.toString();
    final versions = (entry['video_versions'] as List?)?.whereType<Map>().toList() ?? const [];
    final videos = uniqueUrls(versions.map((v) => v['url']?.toString()));
    if (videos.isEmpty && (image == null || image.isEmpty)) return null;
    return _Item(image: image, videos: videos);
  }

  static _Item? _itemFromNode(Map node) {
    final image = node['display_url']?.toString() ?? node['display_src']?.toString();
    final video = node['video_url']?.toString();
    final isVideo = node['is_video'] == true || node['__typename'] == 'GraphVideo';
    if (isVideo && (video == null || video.isEmpty)) return null;
    if (video == null && (image == null || image.isEmpty)) return null;
    return _Item(image: image, videos: uniqueUrls([video]));
  }

  static MediaInfo _build({
    required String code,
    required String pageUrl,
    required List<_Item> items,
    String? caption,
    String? username,
    int? duration,
  }) {
    if (items.isEmpty) throw StateError('This Instagram post has nothing to download.');
    final title = cleanTitle(caption ?? '', fallback: username == null ? 'Instagram' : 'Instagram post by @$username');
    final thumb = items.first.image;
    final options = <QualityOption>[];
    var photos = <String>[];
    if (items.length == 1 && items.first.videos.isNotEmpty) {
      final videos = items.first.videos;
      options.add(QualityOption(id: 'ig-hd', label: 'HD', ext: 'mp4', kind: MediaKind.video, directUrl: videos.first));
      if (videos.length > 1 && videos.last != videos.first) {
        options.add(QualityOption(id: 'ig-sd', label: 'SD', ext: 'mp4', kind: MediaKind.video, directUrl: videos.last));
      }
      options.add(QualityOption(id: 'ig-audio', label: 'Audio', ext: 'm4a', kind: MediaKind.audio, directUrl: videos.last));
    } else {
      photos = [for (final item in items) item.image ?? item.videos.first];
      final hasVideo = items.any((item) => item.videos.isNotEmpty);
      options.add(QualityOption(
        id: 'ig-photos',
        label: hasVideo ? 'Album' : 'Photos',
        ext: 'jpg',
        kind: MediaKind.photo,
        photoUrls: [for (final item in items) item.videos.isNotEmpty ? item.videos.first : item.image!],
      ));
      if (!hasVideo && photos.length > 1) {
        options.add(QualityOption(id: 'ig-slideshow', label: 'Video', ext: 'mp4', kind: MediaKind.video, photoUrls: photos));
      }
    }
    return MediaInfo(
      id: code,
      title: title,
      author: username,
      thumbnail: thumb,
      duration: duration,
      webpageUrl: pageUrl,
      platform: PlatformId.instagram,
      options: options,
      photos: photos,
    );
  }
}

class _Item {
  const _Item({required this.image, required this.videos});
  final String? image;
  final List<String> videos;
}
