import 'dart:convert';
import 'dart:io';

import '../../models/media.dart';
import '../link_parser.dart';
import '../net.dart';

/// Reddit posts from the public JSON. Reddit refuses most unknown clients
/// but serves link-preview bots, so that user agent goes first.
class RedditClient {
  RedditClient(this.net);
  final NetClient net;

  Future<MediaInfo> fetch(String pageUrl) async {
    var url = pageUrl;
    var id = LinkParser.redditId(url);
    if (id == null) {
      url = await LinkParser.follow(url, userAgent: NetHints.botUa) ?? url;
      id = LinkParser.redditId(url);
    }
    if (id == null) throw StateError('This Reddit link does not point to a post.');
    final attempts = [
      ('https://old.reddit.com/comments/$id.json?raw_json=1', NetHints.botUa),
      ('https://www.reddit.com/comments/$id.json?raw_json=1', NetHints.botUa),
      ('https://www.reddit.com/comments/$id.json?raw_json=1', NetHints.desktopUa),
    ];
    Object? last;
    for (final (endpoint, agent) in attempts) {
      try {
        final body = await net.get(endpoint, headers: {'Accept': 'application/json'}, userAgent: agent);
        final post = postFrom(jsonDecode(body));
        if (post == null) continue;
        final video = redditVideo(post);
        String? manifest;
        final dash = video?['dash_url']?.toString();
        if (dash != null && dash.isNotEmpty) {
          try {
            manifest = await net.get(dash, userAgent: NetHints.desktopUa);
          } catch (_) {}
        }
        String? audioGuess;
        if (video != null && manifest == null && video['has_audio'] != false) {
          audioGuess = await _probeAudio(videoBase(video['fallback_url']?.toString() ?? ''));
        }
        return parse(post, pageUrl: 'https://www.reddit.com/comments/$id', manifest: manifest, audioGuess: audioGuess);
      } on StateError catch (error) {
        last = error;
        break;
      } catch (error) {
        last = error;
      }
    }
    throw last is StateError ? last : StateError('Could not load this Reddit post. Try again.');
  }

  /// The post itself, or the original when this one is a crosspost.
  static Map<String, dynamic>? postFrom(Object? json) {
    final listing = json is List && json.isNotEmpty ? json.first : json;
    final children = (listing as Map?)?['data']?['children'];
    if (children is! List || children.isEmpty) return null;
    final post = (children.first as Map?)?['data'];
    if (post is! Map) return null;
    final parents = post['crosspost_parent_list'];
    if (parents is List && parents.isNotEmpty && parents.first is Map && !_hasMedia(post)) {
      return Map<String, dynamic>.from(parents.first as Map);
    }
    return Map<String, dynamic>.from(post);
  }

  static bool _hasMedia(Map post) =>
      redditVideo(post) != null || post['is_gallery'] == true || post['post_hint'] == 'image';

  static Map? redditVideo(Map post) {
    for (final holder in [post['secure_media'], post['media']]) {
      final video = holder is Map ? holder['reddit_video'] : null;
      if (video is Map) return video;
    }
    return null;
  }

  static String videoBase(String fallback) {
    final clean = fallback.split('?').first;
    final slash = clean.lastIndexOf('/');
    return slash < 0 ? clean : clean.substring(0, slash + 1);
  }

  /// Video heights with their files (best first) and the audio file, from a
  /// DASHPlaylist.mpd.
  static ({List<(int, String)> videos, String? audio}) readManifest(String mpd) {
    final videos = <(int, String)>[];
    String? audio;
    var audioBandwidth = -1;
    for (final set in RegExp(r'<AdaptationSet\b([^>]*)>([\s\S]*?)</AdaptationSet>').allMatches(mpd)) {
      final head = set.group(1)!;
      final isAudio = head.contains('contentType="audio"') || set.group(2)!.contains('mimeType="audio');
      for (final rep in RegExp(r'<Representation\b([^>]*)>([\s\S]*?)</Representation>').allMatches(set.group(2)!)) {
        final attrs = rep.group(1)!;
        final file = RegExp(r'<BaseURL>([^<]+)</BaseURL>').firstMatch(rep.group(2)!)?.group(1)?.trim();
        if (file == null) continue;
        if (isAudio) {
          final bandwidth = int.tryParse(RegExp(r'bandwidth="(\d+)"').firstMatch(attrs)?.group(1) ?? '') ?? 0;
          if (bandwidth > audioBandwidth) {
            audioBandwidth = bandwidth;
            audio = file;
          }
        } else {
          final height = int.tryParse(RegExp(r'height="(\d+)"').firstMatch(attrs)?.group(1) ?? '');
          if (height != null) videos.add((height, file));
        }
      }
    }
    videos.sort((a, b) => b.$1.compareTo(a.$1));
    return (videos: videos, audio: audio);
  }

  Future<String?> _probeAudio(String base) async {
    if (base.isEmpty) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      for (final name in const ['CMAF_AUDIO_128.mp4', 'DASH_AUDIO_128.mp4', 'CMAF_AUDIO_64.mp4', 'DASH_AUDIO_64.mp4', 'DASH_audio.mp4', 'audio']) {
        try {
          final request = await client.headUrl(Uri.parse('$base$name'));
          request.headers.set(HttpHeaders.userAgentHeader, NetHints.desktopUa);
          final response = await request.close();
          await response.drain<void>();
          if (response.statusCode == 200) return '$base$name';
        } catch (_) {}
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static MediaInfo parse(Map<String, dynamic> post, {required String pageUrl, String? manifest, String? audioGuess}) {
    final id = post['id']?.toString() ?? LinkParser.redditId(pageUrl) ?? '';
    final title = cleanTitle(post['title']?.toString() ?? '', fallback: 'Reddit post');
    final author = post['author']?.toString();
    final thumb = _preview(post);
    final options = <QualityOption>[];
    var photos = <String>[];
    int? duration;

    final video = redditVideo(post);
    if (video != null) {
      final base = videoBase(video['fallback_url']?.toString() ?? '');
      duration = (video['duration'] as num?)?.round();
      final read = manifest == null ? null : readManifest(manifest);
      final hasAudio = video['has_audio'] != false && video['is_gif'] != true;
      final audio = !hasAudio
          ? null
          : read?.audio != null
              ? '$base${read!.audio}'
              : audioGuess;
      final videos = [
        for (final (height, file) in read?.videos ?? const <(int, String)>[]) (height, '$base$file'),
      ];
      if (videos.isEmpty) {
        final fallback = video['fallback_url']?.toString();
        if (fallback == null) throw StateError('This Reddit video is still processing.');
        videos.add(((video['height'] as num?)?.toInt() ?? 0, fallback));
      }
      if (video['is_gif'] == true) {
        options.add(QualityOption(id: 'rd-gif', label: 'GIF', ext: 'mp4', kind: MediaKind.video, directUrl: videos.first.$2));
      } else {
        final best = videos.first;
        options.add(QualityOption(id: 'rd-hd', label: 'HD', ext: 'mp4', kind: MediaKind.video, height: best.$1, directUrl: best.$2, audioUrl: audio));
        final sd = videos.firstWhere((v) => v.$1 <= best.$1 * 0.6 && v.$1 >= 360, orElse: () => best);
        if (sd != best) {
          options.add(QualityOption(id: 'rd-sd', label: 'SD', ext: 'mp4', kind: MediaKind.video, height: sd.$1, directUrl: sd.$2, audioUrl: audio));
        }
        if (audio != null) {
          options.add(QualityOption(id: 'rd-audio', label: 'Audio', ext: 'm4a', kind: MediaKind.audio, directUrl: audio));
        }
      }
    } else if (post['is_gallery'] == true) {
      final metadata = post['media_metadata'] as Map? ?? const {};
      final urls = <String>[];
      var hasVideo = false;
      for (final item in ((post['gallery_data'] as Map?)?['items'] as List? ?? const []).whereType<Map>()) {
        final meta = metadata[item['media_id']];
        if (meta is! Map || meta['status'] != 'valid') continue;
        final source = meta['s'] as Map? ?? const {};
        if (meta['e'] == 'AnimatedImage') {
          final mp4 = source['mp4']?.toString() ?? source['gif']?.toString();
          if (mp4 != null) {
            urls.add(mp4);
            hasVideo = true;
          }
          continue;
        }
        final original = _original(item['media_id'].toString(), meta['m']?.toString(), source['u']?.toString());
        final url = original ?? source['u']?.toString();
        if (url != null) urls.add(url);
      }
      if (urls.isEmpty) throw StateError('This Reddit gallery is empty or removed.');
      photos = urls;
      options.add(QualityOption(id: 'rd-photos', label: hasVideo ? 'Album' : 'Photos', ext: 'jpg', kind: MediaKind.photo, photoUrls: urls));
      if (!hasVideo && urls.length > 1) {
        options.add(QualityOption(id: 'rd-slideshow', label: 'Video', ext: 'mp4', kind: MediaKind.video, photoUrls: urls));
      }
    } else {
      final link = (post['url_overridden_by_dest'] ?? post['url'])?.toString() ?? '';
      final variants = ((post['preview'] as Map?)?['images'] as List?)?.firstOrNull?['variants'] as Map?;
      final gifMp4 = (variants?['mp4'] as Map?)?['source']?['url']?.toString();
      final previewVideo = (post['preview'] as Map?)?['reddit_video_preview'] as Map?;
      final lower = link.toLowerCase().split('?').first;
      if (lower.endsWith('.gif') || lower.endsWith('.gifv') || previewVideo != null) {
        final mp4 = gifMp4 ?? previewVideo?['fallback_url']?.toString() ?? (lower.endsWith('.gifv') ? link.replaceFirst(RegExp(r'\.gifv', caseSensitive: false), '.mp4') : null);
        if (mp4 != null) {
          options.add(QualityOption(id: 'rd-gif', label: 'GIF', ext: 'mp4', kind: MediaKind.video, directUrl: mp4));
        }
        if (lower.endsWith('.gif')) {
          photos = [link];
          options.add(QualityOption(id: 'rd-gif-file', label: 'GIF file', ext: 'gif', kind: MediaKind.photo, photoUrls: [link]));
        }
      } else if (post['post_hint'] == 'image' || RegExp(r'\.(jpe?g|png|webp)$').hasMatch(lower)) {
        photos = [link];
        options.add(QualityOption(id: 'rd-photos', label: 'Photos', ext: 'jpg', kind: MediaKind.photo, photoUrls: [link]));
      }
    }
    if (options.isEmpty) throw StateError('This Reddit post has no video or photos to save.');
    return MediaInfo(
      id: id,
      title: title,
      author: author == null ? null : 'u/$author',
      thumbnail: thumb ?? (photos.isNotEmpty && !photos.first.contains('.mp4') ? photos.first : null),
      duration: duration,
      webpageUrl: pageUrl,
      platform: PlatformId.reddit,
      options: options,
      photos: photos,
    );
  }

  /// i.redd.it only answers with the exact extension the file was uploaded
  /// with (.jpeg and .jpg are different files); the preview URL carries it.
  static String? _original(String mediaId, String? mime, String? previewUrl) {
    final fromPreview = previewUrl == null
        ? null
        : RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false).firstMatch(Uri.tryParse(previewUrl)?.path ?? '')?.group(1)?.toLowerCase();
    final ext = fromPreview ??
        switch (mime) {
          'image/jpg' => 'jpg',
          'image/jpeg' => 'jpeg',
          'image/png' => 'png',
          'image/webp' => 'webp',
          _ => null,
        };
    return ext == null ? null : 'https://i.redd.it/$mediaId.$ext';
  }

  static String? _preview(Map post) {
    final images = (post['preview'] as Map?)?['images'];
    if (images is List && images.isNotEmpty) {
      final url = (images.first as Map?)?['source']?['url']?.toString();
      if (url != null && url.startsWith('http')) return url;
    }
    final thumb = post['thumbnail']?.toString();
    return thumb != null && thumb.startsWith('http') ? thumb : null;
  }
}
