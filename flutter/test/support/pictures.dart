import 'dart:io' as io;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the network in tests: a picture address maps to a file on
/// this machine, and any other address fails at once.
class LocalPictures extends Fake implements BaseCacheManager {
  LocalPictures([this.files = const {}]);
  final Map<String, String> files;

  /// Makes every picture the app asks the network for come from [files].
  static void serve([Map<String, String> files = const {}]) {
    CachedNetworkImageProvider.defaultCacheManager = LocalPictures(files);
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    final path = files[url];
    if (path == null) throw io.HttpException('No picture here', uri: Uri.parse(url));
    yield FileInfo(const LocalFileSystem().file(path), FileSource.Cache, DateTime(2100), url);
  }
}
