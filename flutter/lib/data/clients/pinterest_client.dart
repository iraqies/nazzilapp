import 'dart:convert';

import '../../models/media.dart';
import '../link_parser.dart';
import '../net.dart';

/// Pins through the web app's PinResource endpoint, with the public widget
/// API as the fallback. Both answer without a login.
class PinterestClient {
  PinterestClient(this.net);
  final NetClient net;

  Future<MediaInfo> fetch(String pageUrl) async {
    final id = LinkParser.pinId(pageUrl);
    if (id == null) throw StateError('This Pinterest link does not point to a pin.');
    final pin = await _load(id);
    final items = await Future.wait(itemsOf(pin).map(withCmaf));
    return build(pin, items, pageUrl: pageUrl, id: id);
  }

  Future<Map<String, dynamic>> _load(String id) async {
    Object? last;
    try {
      final data = Uri.encodeQueryComponent(jsonEncode({
        'options': {'id': id, 'field_set_key': 'detailed'},
        'context': <String, Object>{},
      }));
      final body = await net.get(
        'https://www.pinterest.com/resource/PinResource/get/?source_url=%2Fpin%2F$id%2F&data=$data',
        headers: {'Accept': 'application/json', 'X-Pinterest-PWS-Handler': 'www/pin/[id].js'},
        userAgent: NetHints.desktopUa,
      );
      final pin = ((jsonDecode(body) as Map?)?['resource_response'] as Map?)?['data'];
      if (pin is Map && pin.isNotEmpty) return Map<String, dynamic>.from(pin);
    } catch (error) {
      last = error;
    }
    try {
      final body = await net.get(
        'https://widgets.pinterest.com/v3/pidgets/pins/info/?pin_ids=$id',
        headers: {'Accept': 'application/json'},
        userAgent: NetHints.desktopUa,
      );
      final pins = (jsonDecode(body) as Map?)?['data'];
      if (pins is List && pins.isNotEmpty && pins.first is Map) return Map<String, dynamic>.from(pins.first as Map);
    } catch (error) {
      last = error;
    }
    if (last case final Object error when error is StateError || connectionFailed(error)) throw error;
    throw StateError('Could not load this pin. It may be private or deleted.');
  }

  /// Some pins only offer HLS. Pinterest's HLS points into one CMAF file per
  /// rendition, so the whole file can be fetched without walking segments.
  Future<PinItem> withCmaf(PinItem item) async {
    final hls = item.hls;
    if (item.videos.isNotEmpty || hls == null) return item;
    try {
      final master = readMaster(await net.get(hls, userAgent: NetHints.desktopUa), hls);
      if (master == null) return item;
      Future<String?> fileOf(String? playlist) async =>
          playlist == null ? null : mapUri(await net.get(playlist, userAgent: NetHints.desktopUa), playlist);
      final audio = await fileOf(master.audio);
      final videos = <(String, int)>[];
      for (final variant in master.variants) {
        final file = await fileOf(variant.$1);
        if (file != null) videos.add((file, variant.$2));
      }
      if (videos.isEmpty) return item;
      return PinItem(image: item.image, videos: videos, audio: audio, seconds: item.seconds);
    } catch (_) {
      return item;
    }
  }

  static List<PinItem> itemsOf(Map<String, dynamic> pin) {
    final image = _image(pin['images']);
    final pages = ((pin['story_pin_data'] as Map?)?['pages'] as List?)?.whereType<Map>().toList() ?? const [];
    final main = _video(pin['videos'] as Map?, image);
    if (main != null) return [main];
    final items = <PinItem>[];
    for (final page in pages) {
      for (final block in (page['blocks'] as List? ?? const []).whereType<Map>()) {
        final blockImage = _image((block['image'] as Map?)?['images']);
        final video = _video(block['video'] as Map?, blockImage ?? image);
        if (video != null) {
          items.add(video);
        } else if (blockImage != null) {
          items.add(PinItem(image: blockImage));
        }
      }
    }
    final slots = ((pin['carousel_data'] as Map?)?['carousel_slots'] as List?)?.whereType<Map>() ?? const [];
    if (items.isEmpty) {
      for (final slot in slots) {
        final slotImage = _image(slot['images']);
        if (slotImage != null) items.add(PinItem(image: slotImage));
      }
    }
    if (items.isEmpty && image != null) items.add(PinItem(image: image));
    return items;
  }

  static PinItem? _video(Map? video, String? image) {
    final list = video?['video_list'];
    if (list is! Map || list.isEmpty) return null;
    final mp4 = <(String, int)>[];
    String? hls;
    num? millis;
    for (final entry in list.values.whereType<Map>()) {
      final url = entry['url']?.toString();
      if (url == null || !url.startsWith('http')) continue;
      millis ??= entry['duration'] as num?;
      if (url.contains('.m3u8')) {
        hls ??= url;
      } else if (url.contains('.mp4')) {
        mp4.add((url, (entry['height'] as num?)?.toInt() ?? 0));
      }
    }
    if (mp4.isEmpty && hls == null) return null;
    mp4.sort((a, b) => b.$2.compareTo(a.$2));
    final thumb = list.values.whereType<Map>().map((e) => e['thumbnail']?.toString()).whereType<String>().firstOrNull;
    return PinItem(
      image: image ?? thumb,
      videos: _distinct(mp4),
      hls: hls,
      seconds: millis == null ? null : (millis / 1000).round(),
    );
  }

  static String? _image(Object? images) {
    if (images is! Map) return null;
    final original = images['orig'] ?? images['originals'];
    if (original is Map && original['url'] != null) return original['url'].toString();
    var best = 0;
    String? url;
    for (final entry in images.values.whereType<Map>()) {
      final width = (entry['width'] as num?)?.toInt() ?? 0;
      if (entry['url'] != null && width >= best) {
        best = width;
        url = entry['url'].toString();
      }
    }
    return url;
  }

  static List<(String, int)> _distinct(List<(String, int)> videos) {
    final seen = <String>{};
    return [for (final v in videos) if (seen.add(v.$1)) v];
  }

  /// Variants best first, plus the audio rendition they share.
  static ({List<(String, int)> variants, String? audio})? readMaster(String body, String base) {
    final lines = const LineSplitter().convert(body).map((l) => l.trim()).toList();
    String? audio;
    final variants = <(String, int)>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('#EXT-X-MEDIA:') && line.contains('TYPE=AUDIO')) {
        final uri = RegExp(r'URI="([^"]+)"').firstMatch(line)?.group(1);
        if (uri != null) audio ??= Uri.parse(base).resolve(uri).toString();
      } else if (line.startsWith('#EXT-X-STREAM-INF:')) {
        final height = int.tryParse(RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(line)?.group(1) ?? '') ?? 0;
        final next = lines.skip(i + 1).firstWhere((l) => l.isNotEmpty && !l.startsWith('#'), orElse: () => '');
        if (next.isNotEmpty) variants.add((Uri.parse(base).resolve(next).toString(), height));
      }
    }
    if (variants.isEmpty) return null;
    variants.sort((a, b) => b.$2.compareTo(a.$2));
    return (variants: variants, audio: audio);
  }

  /// The single file behind a byte-range CMAF playlist, or null when the
  /// playlist is made of separate segments.
  static String? mapUri(String body, String base) {
    final map = RegExp(r'#EXT-X-MAP:URI="([^"]+)"').firstMatch(body)?.group(1);
    if (map == null) return null;
    final segments = const LineSplitter()
        .convert(body)
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toSet();
    if (segments.length > 1 || (segments.isNotEmpty && segments.first != map)) return null;
    return Uri.parse(base).resolve(map).toString();
  }

  static MediaInfo build(Map<String, dynamic> pin, List<PinItem> items, {required String pageUrl, required String id}) {
    if (items.isEmpty) throw StateError('This pin has no video or image.');
    final creator = (pin['native_creator'] as Map?) ?? (pin['pinner'] as Map?) ?? const {};
    final author = creator['full_name']?.toString().trim();
    final caption = [pin['title'], pin['grid_title'], pin['description'], pin['seo_alt_text'], pin['auto_alt_text']]
        .map((v) => decodeHtmlEntities(v?.toString() ?? '').trim())
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    final title = cleanTitle(caption, fallback: author == null || author.isEmpty ? 'Pinterest pin' : 'Pin by $author');
    final options = <QualityOption>[];
    var photos = <String>[];
    final single = items.length == 1 ? items.first : null;
    if (single != null && single.videos.isNotEmpty) {
      final best = single.videos.first;
      options.add(QualityOption(
        id: 'pin-hd',
        label: 'HD',
        ext: 'mp4',
        kind: MediaKind.video,
        height: best.$2 == 0 ? null : best.$2,
        directUrl: best.$1,
        audioUrl: single.audio,
      ));
      final sd = single.videos.skip(1).where((v) => v.$2 >= 360 && v.$2 <= best.$2 * 0.75).firstOrNull;
      if (sd != null) {
        options.add(QualityOption(id: 'pin-sd', label: 'SD', ext: 'mp4', kind: MediaKind.video, height: sd.$2, directUrl: sd.$1, audioUrl: single.audio));
      }
      final audio = single.audio;
      options.add(audio == null
          ? QualityOption(id: 'pin-audio', label: 'Audio', ext: 'mp4', kind: MediaKind.audio, directUrl: best.$1)
          : QualityOption(id: 'pin-audio', label: 'Audio', ext: 'm4a', kind: MediaKind.audio, directUrl: audio));
    } else {
      final hasVideo = items.any((item) => item.videos.isNotEmpty);
      photos = [for (final item in items) item.image ?? item.videos.first.$1];
      final gif = single?.image?.toLowerCase().endsWith('.gif') ?? false;
      options.add(QualityOption(
        id: 'pin-photos',
        label: hasVideo ? 'Album' : (gif ? 'GIF' : 'Photos'),
        ext: gif ? 'gif' : 'jpg',
        kind: MediaKind.photo,
        photoUrls: [for (final item in items) item.videos.isNotEmpty ? item.videos.first.$1 : item.image!],
      ));
      if (!hasVideo && !gif && photos.length > 1) {
        options.add(QualityOption(id: 'pin-slideshow', label: 'Video', ext: 'mp4', kind: MediaKind.video, photoUrls: photos));
      }
    }
    return MediaInfo(
      id: id,
      title: title,
      author: author == null || author.isEmpty ? null : author,
      thumbnail: items.first.image,
      duration: single?.seconds,
      webpageUrl: pageUrl,
      platform: PlatformId.pinterest,
      options: options,
      photos: photos,
    );
  }
}

class PinItem {
  const PinItem({this.image, this.videos = const [], this.hls, this.audio, this.seconds});
  final String? image;

  /// (url, height), best first.
  final List<(String, int)> videos;
  final String? hls;

  /// Separate audio track to join with [videos], when they have none.
  final String? audio;
  final int? seconds;
}
