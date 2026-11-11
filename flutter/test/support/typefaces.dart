import 'dart:io';

import 'package:flutter/services.dart';

/// The typefaces the app ships, as `pubspec.yaml` lists them: each family and its files.
Map<String, List<File>> shippedTypefaces() {
  final families = <String, List<File>>{};
  var family = '';
  for (final line in File('pubspec.yaml').readAsLinesSync()) {
    final named = RegExp(r'^\s*- family:\s*(.+?)\s*$').firstMatch(line);
    final file = RegExp(r'^\s*- asset:\s*(\S+)\s*$').firstMatch(line);
    if (named != null) family = named.group(1)!;
    if (file != null) (families[family] ??= []).add(File(file.group(1)!));
  }
  return families;
}

/// Gives a test the app's own typefaces, so words measure as they do on a phone.
Future<void> loadShippedTypefaces() async {
  for (final MapEntry(key: family, value: files) in shippedTypefaces().entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }
}

/// What a font file says of itself: how heavy it is, how many units its body has,
/// and how far it reaches above and below the line, in those units.
({int weight, int body, int above, int below}) typefaceFacts(File file) {
  final data = ByteData.sublistView(file.readAsBytesSync());
  int table(String tag) {
    for (var i = 0; i < data.getUint16(4); i++) {
      final entry = 12 + i * 16;
      if (String.fromCharCodes([for (var k = 0; k < 4; k++) data.getUint8(entry + k)]) == tag) {
        return data.getUint32(entry + 8);
      }
    }
    throw StateError('${file.path} has no $tag table');
  }

  return (
    weight: data.getUint16(table('OS/2') + 4),
    body: data.getUint16(table('head') + 18),
    above: data.getInt16(table('hhea') + 4),
    below: -data.getInt16(table('hhea') + 6),
  );
}
