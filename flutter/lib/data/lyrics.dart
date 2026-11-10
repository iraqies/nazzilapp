import 'dart:convert';

class LyricsHit {
  const LyricsHit({required this.plain, this.synced});
  final String plain;
  final String? synced;
  String get forTag => (synced != null && synced!.trim().isNotEmpty) ? synced! : plain;
}

class LyricsClient {
  LyricsClient(this.getJson);
  final Future<String> Function(Uri uri) getJson;

  Future<LyricsHit?> find(String title, String? author, int? durationSec) async {
    final names = splitNames(title, author);
    if (names.track.length < 2) return null;
    try {
      return await _get(names.track, names.artist, durationSec) ??
          await _get(names.track, names.artist, null) ??
          await _search(names.track, names.artist, durationSec);
    } catch (_) {
      return null;
    }
  }

  Future<LyricsHit?> _get(String track, String artist, int? durationSec) async {
    if (artist.isEmpty) return null;
    final uri = Uri.https('lrclib.net', '/api/get', {
      'track_name': track,
      'artist_name': artist,
      if (durationSec != null && durationSec > 0) 'duration': '$durationSec',
    });
    return _hit(await getJson(uri));
  }

  Future<LyricsHit?> _search(String track, String artist, int? durationSec) async {
    final uri = Uri.https('lrclib.net', '/api/search', {
      'track_name': track,
      if (artist.isNotEmpty) 'artist_name': artist else 'q': track,
    });
    final raw = jsonDecode(await getJson(uri));
    if (raw is! List) return null;
    Map<String, dynamic>? best;
    var bestScore = 1 << 20;
    for (final item in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final synced = (map['syncedLyrics'] as String?)?.trim();
      final plain = (map['plainLyrics'] as String?)?.trim();
      if ((synced == null || synced.isEmpty) && (plain == null || plain.isEmpty)) continue;
      final dur = (map['duration'] as num?)?.toInt() ?? 0;
      final delta = durationSec != null && durationSec > 0 && dur > 0
          ? (dur - durationSec).abs()
          : 20;
      final score = (synced != null && synced.isNotEmpty ? 0 : 50) + delta;
      if (score < bestScore) {
        bestScore = score;
        best = map;
      }
    }
    return best == null ? null : _hit(jsonEncode(best));
  }

  LyricsHit? _hit(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map) return null;
    final synced = lineSynced(json['syncedLyrics'] as String?);
    var plain = (json['plainLyrics'] as String?)?.trim();
    if ((plain == null || plain.isEmpty) && synced != null) {
      plain = synced
          .split('\n')
          .map((line) => line.replaceFirst(_lineStamps, '').trim())
          .where((line) => line.isNotEmpty && !line.startsWith('['))
          .join('\n');
    }
    if ((plain == null || plain.isEmpty) && (synced == null || synced.isEmpty)) return null;
    return LyricsHit(plain: plain ?? '', synced: synced);
  }

  static final _lineStamps = RegExp(r'^(\[\d+:\d+(?:[.:]\d+)?\]\s*)+');
  static final _wordStamps = RegExp(r'<\d+:\d+(?:[.:]\d+)?>\s*');

  /// Word-by-word "<mm:ss.xx>" marks are an LRC extension most players print
  /// as text, so only the line times are kept.
  static String? lineSynced(String? lrc) {
    final text = lrc?.trim();
    if (text == null || text.isEmpty) return null;
    final lines = [
      for (final line in text.split(RegExp(r'\r?\n')))
        line.replaceAll(_wordStamps, '').replaceAll(RegExp(r'\s+$'), ''),
    ];
    final out = lines.join('\n').trim();
    return out.isEmpty ? null : out;
  }

  static ({String track, String artist}) splitNames(String title, String? author) {
    var track = title
        .replaceAll(
          RegExp(
            r'\s*[\(\[][^)\]]*(official|video|audio|lyric|lyrics|hd|4k|mv|visualizer|topic)[^)\]]*[\)\]]',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s*(official\s*(music\s*)?(video|audio)|lyrics|visualizer)\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim()
        .replaceAll(RegExp(r'''^["'\-–—]+|["'\-–—]+$'''), '');
    var artist = (author?.split(',').first.split(' - ').first.trim() ?? '')
        .replaceFirst(RegExp(r'\s*(VEVO|Official|Topic)$', caseSensitive: false), '')
        .trim();
    final parts = track.split(RegExp(r'\s+[-–—]\s+'));
    if (parts.length == 2 && parts[0].trim().isNotEmpty && parts[1].trim().isNotEmpty) {
      // Labels and fan channels upload as "Artist - Song", so the title
      // names the singer better than the channel does.
      artist = parts[0].trim();
      track = parts[1].trim();
    }
    return (track: track.isEmpty ? title.trim() : track, artist: artist);
  }
}
