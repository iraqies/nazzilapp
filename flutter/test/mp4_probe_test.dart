import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/data/mp4_probe.dart';

List<int> _box(String type, List<int> body) {
  final size = body.length + 8;
  return [size >> 24 & 0xFF, size >> 16 & 0xFF, size >> 8 & 0xFF, size & 0xFF, ...latin1.encode(type), ...body];
}

List<int> _trak(String handler, int samples) => _box('trak', [
  ..._box('tkhd', List.filled(84, 0)),
  ..._box('mdia', [
    ..._box('hdlr', [0, 0, 0, 0, 0, 0, 0, 0, ...latin1.encode(handler), ...List.filled(13, 0)]),
    ..._box('minf', [
      ..._box('stbl', [
        ..._box('stsz', [
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          samples >> 24,
          samples >> 16 & 0xFF,
          samples >> 8 & 0xFF,
          samples & 0xFF,
        ]),
      ]),
    ]),
  ]),
]);

void main() {
  test('counts only video track samples', () {
    final moov = Uint8List.fromList(
      _box('moov', [..._box('mvhd', List.filled(100, 0)), ..._trak('soun', 431), ..._trak('vide', 300)]),
    );
    expect(Mp4Probe.samplesInMoov(moov), 300);
  });

  test('an empty video track or audio-only file counts as no video', () async {
    expect(Mp4Probe.samplesInMoov(Uint8List.fromList(_box('moov', _trak('vide', 0)))), 0);
    final dir = Directory.systemTemp.createTempSync('mp4');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/a.m4a')
      ..writeAsBytesSync([
        ..._box('ftyp', latin1.encode('M4A \x00\x00\x00\x00')),
        ..._box('mdat', [1, 2, 3]),
        ..._box('moov', _trak('soun', 9)),
      ]);
    expect(await Mp4Probe.videoSamples(file), 0);
  });

  test('reads files written by ffmpeg', () async {
    final dir = Directory.systemTemp.createTempSync('mp4');
    addTearDown(() => dir.deleteSync(recursive: true));
    Future<int> make(String name, List<String> args) async {
      final out = '${dir.path}/$name';
      final run = await Process.run('ffmpeg', ['-v', 'error', '-y', ...args, out]);
      expect(run.exitCode, 0, reason: run.stderr.toString());
      return Mp4Probe.videoSamples(File(out));
    }

    final sine = ['-f', 'lavfi', '-i', 'sine=d=2'];
    final color = ['-f', 'lavfi', '-i', 'color=s=64x64:r=30:d=2'];
    expect(
      await make('v.mp4', [...color, ...sine, '-c:v', 'mpeg4', '-c:a', 'aac', '-shortest', '-movflags', '+faststart']),
      60,
    );
    expect(await make('late.mp4', [...color, '-c:v', 'mpeg4']), 60);
    expect(await make('a.m4a', [...sine, '-c:a', 'aac']), 0);
  }, skip: Process.runSync('which', ['ffmpeg']).exitCode == 0 ? false : 'ffmpeg not installed');
}
