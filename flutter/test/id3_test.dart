import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/data/id3.dart';

Map<String, List<int>> _frames(Uint8List tag) {
  expect(latin1.decode(tag.sublist(0, 3)), 'ID3');
  expect(tag[3], 3);
  final size = tag[6] << 21 | tag[7] << 14 | tag[8] << 7 | tag[9];
  expect(size, tag.length - 10);
  final frames = <String, List<int>>{};
  var at = 10;
  while (at + 10 <= tag.length && tag[at] != 0) {
    final id = latin1.decode(tag.sublist(at, at + 4));
    final len = tag[at + 4] << 24 | tag[at + 5] << 16 | tag[at + 6] << 8 | tag[at + 7];
    frames[id] = tag.sublist(at + 10, at + 10 + len);
    at += 10 + len;
  }
  return frames;
}

String _utf16(List<int> bytes) {
  final units = <int>[for (var i = 0; i + 1 < bytes.length; i += 2) bytes[i] | bytes[i + 1] << 8];
  return String.fromCharCodes(units).replaceAll('\u0000', '');
}

void main() {
  const synced = '[00:01.50] Never gonna give you up\n[00:04.2] Never gonna let you down\n[00:06.00]';

  test('writes cover, names and both lyric frames', () {
    final jpeg = [0xFF, 0xD8, ...List.filled(500, 7)];
    final frames = _frames(
      Id3Tag(title: 'Never Gonna Give You Up', artist: 'Rick Astley', jpeg: jpeg, syncedLyrics: synced).bytes(),
    );
    expect(frames.keys, containsAll(['APIC', 'TIT2', 'TPE1', 'TALB', 'USLT', 'SYLT']));
    expect(latin1.decode(frames['APIC']!.sublist(1, 11)), 'image/jpeg');
    expect(frames['APIC']!.sublist(14), jpeg);
    expect(_utf16(frames['TIT2']!.sublist(3)), 'Never Gonna Give You Up');
    expect(_utf16(frames['TPE1']!.sublist(3)), 'Rick Astley');
    expect(_utf16(frames['USLT']!.sublist(10)), contains('[00:04.2] Never gonna let you down'));
    final sylt = frames['SYLT']!;
    expect(sylt.sublist(4, 6), [2, 1]);
    final firstStamp = sylt.sublist(10 + 2 + 'Never gonna give you up'.length * 2 + 2).take(4).toList();
    expect(firstStamp, [0, 0, 0x05, 0xDC]);
  });

  test('parses LRC like the Android tagger', () {
    expect(Id3Tag.parseLrc(synced), [(1500, 'Never gonna give you up'), (4200, 'Never gonna let you down')]);
  });

  test('plain lyrics only gives USLT without SYLT, no cover gives no APIC', () {
    final frames = _frames(const Id3Tag(title: 'Song', plainLyrics: 'line one\nline two').bytes());
    expect(frames.containsKey('SYLT'), isFalse);
    expect(frames.containsKey('APIC'), isFalse);
    expect(_utf16(frames['TPE1']!.sublist(3)), 'Nazzil');
    expect(_utf16(frames['USLT']!.sublist(10)), 'line one\nline two');
  });

  test('replaces an existing tag instead of stacking', () {
    final dir = Directory.systemTemp.createTempSync('id3');
    addTearDown(() => dir.deleteSync(recursive: true));
    final audio = [0xFF, 0xFB, 0x90, 0x64, ...List.filled(64, 1)];
    final file = File('${dir.path}/song.mp3')..writeAsBytesSync(audio);
    const Id3Tag(title: 'First').writeTo(file);
    const Id3Tag(title: 'Second').writeTo(file);
    final data = file.readAsBytesSync();
    final body = Id3Tag.stripTag(data);
    expect(body, audio);
    expect(_utf16(_frames(data.sublist(0, data.length - audio.length))['TIT2']!.sublist(3)), 'Second');
  });
}
