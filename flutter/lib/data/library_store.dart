import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/media.dart';

class LibraryStore {
  static const _key = 'nazzil.library.v2';

  Future<List<LibraryItem>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((e) => LibraryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<LibraryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.take(200).map((e) => e.toJson()).toList()),
    );
  }

  /// Whether a finished download still has a file. A file with nothing in it is not one:
  /// a phone that loses power as a download lands keeps the name and none of the bytes.
  bool stillHave(LibraryItem item) {
    if (item.active) return false;
    return item.paths.any((path) {
      if (path.isEmpty) return false;
      final stat = FileStat.statSync(path);
      return stat.type == FileSystemEntityType.file && stat.size > 0;
    });
  }

  LibraryItem? findKept({
    required String videoKey,
    required String quality,
    required List<LibraryItem> items,
  }) {
    for (final item in items) {
      if (item.quality.toLowerCase() == quality.toLowerCase() &&
          item.videoKey == videoKey &&
          (item.active || stillHave(item))) {
        return item;
      }
    }
    return null;
  }

  LibraryItem? nextQueued(List<LibraryItem> items) {
    final queued = items.where((e) => e.status == LibraryItem.statusQueued).toList();
    return queued.isEmpty ? null : queued.last;
  }

  List<LibraryItem> recoverInterrupted(List<LibraryItem> items) {
    return [
      for (final item in items)
        item.status == LibraryItem.statusDownloading
            ? item.copyWith(status: LibraryItem.statusQueued, error: '')
            : item,
    ];
  }
}
