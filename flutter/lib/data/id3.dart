import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// ID3v2.3 tags for MP3s where no native tagger exists (Windows, Linux,
/// macOS). Writes the same frames as AudioTagger.kt: cover, title, artist,
/// album, lyrics and synced lyrics.
class Id3Tag {
  const Id3Tag({required this.title, this.artist, this.jpeg, this.plainLyrics, this.syncedLyrics});

  final String title;
  final String? artist;
  final List<int>? jpeg;
  final String? plainLyrics;
  final String? syncedLyrics;

  /// Players that read synced lyrics from USLT expect the LRC text there.
  String get _lyricsText {
    final synced = syncedLyrics?.trim() ?? '';
    return synced.isNotEmpty ? synced : (plainLyrics?.trim() ?? '');
  }

  void writeTo(File mp3) {
    final body = stripTag(mp3.readAsBytesSync());
    final out = BytesBuilder(copy: false)
      ..add(bytes())
      ..add(body);
    mp3.writeAsBytesSync(out.takeBytes(), flush: true);
  }

  Uint8List bytes() {
    final frames = BytesBuilder(copy: false);
    final cover = jpeg;
    if (cover != null && cover.isNotEmpty) {
      frames.add(_frame('APIC', [0, ...latin1.encode('image/jpeg'), 0, 3, 0, ...cover]));
    }
    frames.add(_text('TIT2', title));
    frames.add(_text('TPE1', (artist ?? '').trim().isEmpty ? 'Nazzil' : artist!.trim()));
    frames.add(_text('TALB', title));
    final lyrics = _lyricsText;
    if (lyrics.isNotEmpty) {
      frames.add(_frame('USLT', [1, ...latin1.encode('eng'), 0xFF, 0xFE, 0, 0, 0xFF, 0xFE, ..._utf16le(lyrics), 0, 0]));
    }
    final lines = parseLrc(syncedLyrics ?? '');
    if (lines.isNotEmpty) {
      final sylt = BytesBuilder(copy: false)..add([1, ...latin1.encode('eng'), 2, 1, 0xFF, 0xFE, 0, 0]);
      for (final (millis, words) in lines) {
        sylt
          ..add([0xFF, 0xFE, ..._utf16le(words), 0, 0])
          ..add(_u32(millis));
      }
      frames.add(_frame('SYLT', sylt.takeBytes()));
    }
    frames.add(Uint8List(2048));
    final payload = frames.takeBytes();
    return Uint8List.fromList([0x49, 0x44, 0x33, 3, 0, 0, ..._synchsafe(payload.length), ...payload]);
  }

  static Uint8List stripTag(Uint8List data) {
    if (data.length < 10 || data[0] != 0x49 || data[1] != 0x44 || data[2] != 0x33) return data;
    final size = (data[6] & 0x7F) << 21 | (data[7] & 0x7F) << 14 | (data[8] & 0x7F) << 7 | (data[9] & 0x7F);
    final end = 10 + size;
    return end <= data.length ? Uint8List.sublistView(data, end) : data;
  }

  static List<(int, String)> parseLrc(String text) {
    final rx = RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\]\s*(.*)');
    return [
      for (final line in const LineSplitter().convert(text))
        if (rx.firstMatch(line.trim()) case final m?)
          if (m.group(4)!.trim().isNotEmpty)
            (
              int.parse(m.group(1)!) * 60000 + int.parse(m.group(2)!) * 1000 + _millis(m.group(3) ?? ''),
              m.group(4)!.trim(),
            ),
    ];
  }

  static int _millis(String frac) {
    if (frac.isEmpty) return 0;
    return int.tryParse(frac.length <= 3 ? frac.padRight(3, '0') : frac.substring(0, 3)) ?? 0;
  }

  static List<int> _text(String id, String value) => _frame(id, [1, 0xFF, 0xFE, ..._utf16le(value), 0, 0]);

  static List<int> _frame(String id, List<int> body) => [...latin1.encode(id), ..._u32(body.length), 0, 0, ...body];

  static List<int> _utf16le(String value) => [
        for (final unit in value.codeUnits) ...[unit & 0xFF, unit >> 8],
      ];

  static List<int> _u32(int v) => [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];

  static List<int> _synchsafe(int v) => [(v >> 21) & 0x7F, (v >> 14) & 0x7F, (v >> 7) & 0x7F, v & 0x7F];
}
