import '../../models/media.dart';
import '../link_parser.dart';
import '../net.dart';

class FacebookClient {
  FacebookClient(this.net);
  final NetClient net;

  Future<MediaInfo> fetch(String pageUrl) async {
    final resolved = await LinkParser.resolve(pageUrl);
    final encoded = Uri.encodeQueryComponent(resolved);
    final pages = uniqueUrls([
      resolved,
      resolved.replaceAll('www.facebook.com', 'm.facebook.com'),
      'https://www.facebook.com/plugins/video.php?href=$encoded',
    ]);
    Object? last;
    for (final page in pages) {
      try {
        final html = await net.get(
          page,
          headers: {'Referer': 'https://www.facebook.com/'},
          userAgent: NetHints.desktopUa,
        );
        final urls = uniqueUrls([
          firstGroup(html, [RegExp(r'"browser_native_hd_url"\s*:\s*"([^"]+)"')]),
          firstGroup(html, [RegExp(r'"playable_url_quality_hd"\s*:\s*"([^"]+)"')]),
          firstGroup(html, [RegExp(r'"hd_src"\s*:\s*"([^"]+)"')]),
          firstGroup(html, [RegExp(r'"browser_native_sd_url"\s*:\s*"([^"]+)"')]),
          firstGroup(html, [RegExp(r'"playable_url"\s*:\s*"([^"]+)"')]),
          firstGroup(html, [RegExp(r'"sd_src"\s*:\s*"([^"]+)"')]),
          og(html, 'video:secure_url'),
          og(html, 'video'),
        ]);
        if (urls.isEmpty) continue;
        final hd = urls.first;
        final sd = urls.last;
        return MediaInfo(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: og(html, 'title') ?? 'Facebook video',
          thumbnail: og(html, 'image'),
          webpageUrl: resolved,
          platform: PlatformId.facebook,
          options: [
            QualityOption(
              id: 'fb-hd',
              label: 'HD',
              ext: 'mp4',
              kind: MediaKind.video,
              directUrl: hd,
            ),
            if (sd != hd)
              QualityOption(
                id: 'fb-sd',
                label: 'SD',
                ext: 'mp4',
                kind: MediaKind.video,
                directUrl: sd,
              ),
            QualityOption(
              id: 'fb-audio',
              label: 'Audio',
              ext: 'm4a',
              kind: MediaKind.audio,
              directUrl: hd,
            ),
          ],
        );
      } catch (error) {
        last = error;
      }
    }
    throw last ?? StateError('Could not load this Facebook link');
  }
}
