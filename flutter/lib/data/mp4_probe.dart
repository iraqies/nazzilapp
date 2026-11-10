import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

typedef _Box = ({String type, int body, int end});

/// Reads MP4 boxes directly; FFprobe's media information is not available
/// on every desktop build of the FFmpeg plugin.
abstract final class Mp4Probe {
  /// Number of samples across the file's video tracks (0 when there are none).
  static Future<int> videoSamples(File file) async {
    final raf = await file.open();
    try {
      final length = await raf.length();
      var at = 0;
      while (at + 8 <= length) {
        await raf.setPosition(at);
        final head = await raf.read(16);
        if (head.length < 8) break;
        final box = _header(head, 0, length - at);
        if (box == null) break;
        if (box.type == 'moov') {
          await raf.setPosition(at);
          return samplesInMoov(await raf.read(box.end));
        }
        at += box.end;
      }
      return 0;
    } finally {
      await raf.close();
    }
  }

  /// [moov] is the whole moov box, header included.
  static int samplesInMoov(Uint8List moov) {
    final root = _header(moov, 0, moov.length);
    if (root == null || root.type != 'moov') return 0;
    var total = 0;
    for (final trak in _children(moov, root.body, root.end).where((b) => b.type == 'trak')) {
      final mdia = _child(moov, trak, 'mdia');
      final hdlr = mdia == null ? null : _child(moov, mdia, 'hdlr');
      if (hdlr == null || hdlr.body + 12 > hdlr.end) continue;
      if (latin1.decode(moov.sublist(hdlr.body + 8, hdlr.body + 12)) != 'vide') continue;
      final minf = _child(moov, mdia!, 'minf');
      final stbl = minf == null ? null : _child(moov, minf, 'stbl');
      final stsz = stbl == null ? null : _child(moov, stbl, 'stsz');
      if (stsz == null || stsz.body + 12 > stsz.end) continue;
      total += _u32(moov, stsz.body + 8);
    }
    return total;
  }

  /// Box starting at [at] in [d], at most [limit] bytes long. `body` and
  /// `end` are indices into [d].
  static _Box? _header(Uint8List d, int at, int limit) {
    if (at + 8 > d.length) return null;
    var size = _u32(d, at);
    var header = 8;
    if (size == 1) {
      if (at + 16 > d.length) return null;
      size = _u32(d, at + 8) * 0x100000000 + _u32(d, at + 12);
      header = 16;
    } else if (size == 0) {
      size = limit;
    }
    if (size < header || size > limit) return null;
    return (type: latin1.decode(d.sublist(at + 4, at + 8)), body: at + header, end: at + size);
  }

  static Iterable<_Box> _children(Uint8List d, int start, int end) sync* {
    var at = start;
    while (at + 8 <= end) {
      final box = _header(d, at, end - at);
      if (box == null) return;
      yield box;
      at = box.end;
    }
  }

  static _Box? _child(Uint8List d, _Box parent, String type) {
    for (final box in _children(d, parent.body, parent.end)) {
      if (box.type == type) return box;
    }
    return null;
  }

  static int _u32(Uint8List d, int at) => d[at] << 24 | d[at + 1] << 16 | d[at + 2] << 8 | d[at + 3];
}
