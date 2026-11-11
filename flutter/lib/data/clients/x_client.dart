import 'dart:convert';
import 'dart:math';

import '../../models/media.dart';
import '../link_parser.dart';
import '../net.dart';

/// X / Twitter posts through the public embed API, with fxtwitter as the
/// fallback for posts the embed API hides (age-gated ones, for example).
class XClient {
  XClient(this.net);
  final NetClient net;

  Future<MediaInfo> fetch(String pageUrl) async {
    final id = LinkParser.tweetId(pageUrl);
    if (id == null) throw StateError('This X link does not point to a post.');
    Object? last;
    try {
      final body = await net.get(
        'https://cdn.syndication.twimg.com/tweet-result?id=$id&lang=en&token=${token(id)}',
        headers: {'Accept': 'application/json'},
        userAgent: NetHints.desktopUa,
      );
      final json = jsonDecode(body);
      if (json is Map && json['__typename'] == 'Tweet') {
        return parseEmbed(Map<String, dynamic>.from(json), pageUrl: pageUrl);
      }
    } catch (error) {
      last = error;
    }
    try {
      final body = await net.get(
        'https://api.fxtwitter.com/status/$id',
        headers: {'Accept': 'application/json'},
        userAgent: NetHints.desktopUa,
      );
      final tweet = (jsonDecode(body) as Map?)?['tweet'];
      if (tweet is Map) return parseFx(Map<String, dynamic>.from(tweet), pageUrl: pageUrl);
    } catch (error) {
      last = error;
    }
    if (last case final Object error when error is StateError || connectionFailed(error)) throw error;
    throw StateError('Could not load this X post. It may be private or deleted.');
  }

  /// The token the embed widget sends; the API accepts it as is.
  static String token(String id) {
    var value = int.parse(id) / 1e15 * pi;
    final whole = value.floor();
    final out = StringBuffer(whole.toRadixString(36));
    value -= whole;
    for (var i = 0; i < 10 && value > 0; i++) {
      value *= 36;
      final digit = value.floor();
      out.write(digit.toRadixString(36));
      value -= digit;
    }
    return out.toString().replaceAll('0', '');
  }

  static MediaInfo parseEmbed(Map<String, dynamic> tweet, {required String pageUrl}) {
    final items = <XItem>[];
    for (final media in (tweet['mediaDetails'] as List? ?? const []).whereType<Map>()) {
      final image = media['media_url_https']?.toString();
      if (media['type'] == 'photo') {
        if (image != null) items.add(XItem(image: originalPhoto(image)));
        continue;
      }
      final info = media['video_info'] as Map? ?? const {};
      final videos = bestFirst([
        for (final v in (info['variants'] as List? ?? const []).whereType<Map>())
          if (v['content_type'] == 'video/mp4' && v['url'] != null) (v['url'].toString(), (v['bitrate'] as num?) ?? 0),
      ]);
      if (videos.isEmpty) continue;
      final millis = info['duration_millis'] as num?;
      items.add(XItem(
        image: image,
        videos: videos,
        gif: media['type'] == 'animated_gif',
        seconds: millis == null ? null : (millis / 1000).round(),
      ));
    }
    final quoted = tweet['quoted_tweet'];
    if (items.isEmpty && quoted is Map) return parseEmbed(Map<String, dynamic>.from(quoted), pageUrl: pageUrl);
    final user = tweet['user'] as Map? ?? const {};
    return build(
      id: tweet['id_str']?.toString() ?? LinkParser.tweetId(pageUrl) ?? '',
      text: tweet['text']?.toString() ?? '',
      name: user['name']?.toString(),
      handle: user['screen_name']?.toString(),
      items: items,
      pageUrl: pageUrl,
    );
  }

  static MediaInfo parseFx(Map<String, dynamic> tweet, {required String pageUrl}) {
    final items = <XItem>[];
    final media = tweet['media'] as Map? ?? const {};
    for (final m in (media['all'] as List? ?? const []).whereType<Map>()) {
      final url = m['url']?.toString();
      if (m['type'] == 'photo') {
        if (url != null) items.add(XItem(image: originalPhoto(url)));
        continue;
      }
      final videos = bestFirst([
        for (final v in (m['variants'] as List? ?? const []).whereType<Map>())
          if (v['content_type'] == 'video/mp4' && v['url'] != null) (v['url'].toString(), (v['bitrate'] as num?) ?? 0),
      ]);
      if (videos.isEmpty && url != null && url.contains('.mp4')) videos.add(url);
      if (videos.isEmpty) continue;
      final seconds = num.tryParse(m['duration']?.toString() ?? '');
      items.add(XItem(
        image: m['thumbnail_url']?.toString(),
        videos: videos,
        gif: m['type'] == 'gif',
        seconds: seconds?.round(),
      ));
    }
    final quote = tweet['quote'];
    if (items.isEmpty && quote is Map) return parseFx(Map<String, dynamic>.from(quote), pageUrl: pageUrl);
    final author = tweet['author'] as Map? ?? const {};
    return build(
      id: tweet['id']?.toString() ?? LinkParser.tweetId(pageUrl) ?? '',
      text: tweet['text']?.toString() ?? '',
      name: author['name']?.toString(),
      handle: author['screen_name']?.toString(),
      items: items,
      pageUrl: pageUrl,
    );
  }

  static List<String> bestFirst(List<(String, num)> variants) {
    variants.sort((a, b) => b.$2.compareTo(a.$2));
    return uniqueUrls(variants.map((v) => v.$1));
  }

  /// pbs.twimg.com serves the uploaded size with name=orig.
  static String originalPhoto(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.contains('pbs.twimg.com')) return url;
    final path = uri.path;
    final dot = path.lastIndexOf('.');
    if (dot < 0) return url;
    final format = path.substring(dot + 1);
    return uri.replace(path: path.substring(0, dot), queryParameters: {'format': format, 'name': 'orig'}).toString();
  }

  static MediaInfo build({
    required String id,
    required String text,
    required String? name,
    required String? handle,
    required List<XItem> items,
    required String pageUrl,
  }) {
    if (items.isEmpty) throw StateError('This X post has no video or photos.');
    final caption = text.replaceAll(RegExp(r'https://t\.co/\w+'), '').trim();
    final title = cleanTitle(caption, fallback: handle == null ? 'X post' : 'X post by @$handle');
    final options = <QualityOption>[];
    var photos = <String>[];
    final single = items.length == 1 ? items.first : null;
    if (single != null && single.videos.isNotEmpty) {
      final videos = single.videos;
      if (single.gif) {
        options.add(QualityOption(id: 'x-gif', label: 'GIF', ext: 'mp4', kind: MediaKind.video, directUrl: videos.first));
      } else {
        options.add(QualityOption(id: 'x-hd', label: 'HD', ext: 'mp4', kind: MediaKind.video, height: _height(videos.first), directUrl: videos.first));
        if (videos.length > 1) {
          final sd = videos[videos.length > 2 ? 1 : videos.length - 1];
          options.add(QualityOption(id: 'x-sd', label: 'SD', ext: 'mp4', kind: MediaKind.video, height: _height(sd), directUrl: sd));
        }
        options.add(QualityOption(id: 'x-audio', label: 'Audio', ext: 'mp4', kind: MediaKind.audio, directUrl: videos.first));
      }
    } else {
      photos = [for (final item in items) item.image ?? item.videos.first];
      final hasVideo = items.any((item) => item.videos.isNotEmpty);
      options.add(QualityOption(
        id: 'x-photos',
        label: hasVideo ? 'Album' : 'Photos',
        ext: 'jpg',
        kind: MediaKind.photo,
        photoUrls: [for (final item in items) item.videos.isNotEmpty ? item.videos.first : item.image!],
      ));
      if (!hasVideo && photos.length > 1) {
        options.add(QualityOption(id: 'x-slideshow', label: 'Video', ext: 'mp4', kind: MediaKind.video, photoUrls: photos));
      }
    }
    return MediaInfo(
      id: id,
      title: title,
      author: name ?? (handle == null ? null : '@$handle'),
      thumbnail: items.first.image,
      duration: single?.seconds,
      webpageUrl: pageUrl,
      platform: PlatformId.x,
      options: options,
      photos: photos,
    );
  }

  static int? _height(String url) {
    final match = RegExp(r'/(\d{2,4})x(\d{2,4})/').firstMatch(url);
    return match == null ? null : int.tryParse(match.group(2)!);
  }
}

class XItem {
  const XItem({this.image, this.videos = const [], this.gif = false, this.seconds});
  final String? image;
  final List<String> videos;
  final bool gif;
  final int? seconds;
}
