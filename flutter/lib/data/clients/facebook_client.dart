import '../../models/media.dart';
import '../link_parser.dart';
import '../net.dart';

class FacebookClient {
  FacebookClient(this.net);
  final NetClient net;

  /// The full page carries the title and poster but usually no video links;
  /// the embed player has the links but no title. Both are read.
  Future<MediaInfo> fetch(String pageUrl) async {
    final resolved = await LinkParser.resolve(pageUrl);
    final encoded = Uri.encodeQueryComponent(resolved);
    final pages = uniqueUrls([
      resolved,
      resolved.replaceAll('www.facebook.com', 'm.facebook.com'),
      'https://www.facebook.com/plugins/video.php?href=$encoded',
    ]);
    Object? last;
    ({String title, String? author})? names;
    String? poster;
    String? avif;
    String? videoId = videoIdOf(resolved);
    List<String> urls = const [];
    for (final page in pages) {
      try {
        final html = await net.get(
          page,
          headers: {'Referer': 'https://www.facebook.com/'},
          userAgent: NetHints.desktopUa,
        );
        final found = titleParts(RegExp(r'<title>([^<]*)</title>').firstMatch(html)?.group(1), og(html, 'title'));
        if (names == null && found != null) names = found;
        poster ??= jpegPoster(html);
        final image = og(html, 'image');
        if (image != null && !image.contains('.avif')) poster ??= image;
        avif ??= image;
        videoId ??= firstGroup(html, [RegExp(r'"video_id"\s*:\s*"(\d+)"')]);
        if (urls.isEmpty) {
          urls = uniqueUrls([
            firstGroup(html, [RegExp(r'"browser_native_hd_url"\s*:\s*"([^"]+)"')]),
            firstGroup(html, [RegExp(r'"playable_url_quality_hd"\s*:\s*"([^"]+)"')]),
            firstGroup(html, [RegExp(r'"hd_src"\s*:\s*"([^"]+)"')]),
            firstGroup(html, [RegExp(r'"browser_native_sd_url"\s*:\s*"([^"]+)"')]),
            firstGroup(html, [RegExp(r'"playable_url"\s*:\s*"([^"]+)"')]),
            firstGroup(html, [RegExp(r'"sd_src"\s*:\s*"([^"]+)"')]),
            og(html, 'video:secure_url'),
            og(html, 'video'),
          ]);
        }
        if (urls.isNotEmpty && names != null && poster != null) break;
      } catch (error) {
        last = error;
      }
    }
    if (urls.isEmpty) throw last ?? StateError('Could not load this Facebook link');
    final hd = urls.first;
    final sd = urls.last;
    return MediaInfo(
      id: videoId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: names?.title ?? 'Facebook video',
      author: names?.author,
      thumbnail: poster ?? avif,
      webpageUrl: resolved,
      platform: PlatformId.facebook,
      options: [
        QualityOption(id: 'fb-hd', label: 'HD', ext: 'mp4', kind: MediaKind.video, directUrl: hd),
        if (sd != hd) QualityOption(id: 'fb-sd', label: 'SD', ext: 'mp4', kind: MediaKind.video, directUrl: sd),
        // SD files can carry a much lower audio bitrate than HD.
        QualityOption(id: 'fb-audio', label: 'Audio', ext: 'mp4', kind: MediaKind.audio, directUrl: hd),
      ],
    );
  }

  static String? videoIdOf(String url) {
    final uri = Uri.tryParse(url);
    final v = uri?.queryParameters['v'];
    if (v != null && RegExp(r'^\d+$').hasMatch(v)) return v;
    return RegExp(r'/(?:videos|reel|watch)/(?:[^/]+/)?(\d{6,})').firstMatch(url)?.group(1);
  }

  /// Page titles look like "19M views · 690K reactions | Title | Page".
  static ({String title, String? author})? titleParts(String? pageTitle, String? ogTitle) {
    for (final raw in [pageTitle, ogTitle]) {
      if (raw == null) continue;
      final parts = decodeHtmlEntities(raw).split(' | ').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.length > 1 && RegExp(r'\b(views|reactions|shares|comments|plays)\b', caseSensitive: false).hasMatch(parts.first)) {
        parts.removeAt(0);
      }
      if (parts.isEmpty || (parts.length == 1 && parts.first.toLowerCase() == 'facebook')) continue;
      final author = parts.length > 1 ? parts.removeLast() : null;
      return (title: cleanTitle(parts.join(' | '), fallback: 'Facebook video'), author: author);
    }
    return null;
  }

  static String? jpegPoster(String html) {
    final match = RegExp(r'''https:[^"'\s]*fbcdn\.net/v/t15\.[^"'\s]*\.jpg[^"'\s]*''').firstMatch(html);
    return match == null ? null : decodeHtmlEntities(decodeEscaped(match.group(0)!));
  }
}
