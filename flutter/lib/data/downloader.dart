import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/media.dart';
import 'audio_convert.dart';
import 'extractor.dart';
import 'gallery.dart';
import 'host.dart';
import 'link_parser.dart';
import 'lyrics.dart';
import 'net.dart';

class DownloadResult {
  const DownloadResult({required this.files, required this.photoCount});
  final List<File> files;
  final int photoCount;
}

class MediaDownloader {
  MediaDownloader({
    required this.extractor,
    required this.gallery,
    NetClient? net,
    AudioConverter? converter,
  })  : net = net ?? extractor.net,
        converter = converter ?? AudioConverter();

  final MediaExtractor extractor;
  final GalleryService gallery;
  final NetClient net;
  final AudioConverter converter;

  Future<DownloadResult> download({
    required MediaInfo media,
    required QualityOption option,
    required void Function(double progress) onProgress,
    List<String> resumePaths = const [],
    int completedPhotos = 0,
  }) async {
    final folder = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'media'),
    );
    await folder.create(recursive: true);
    final base = LinkParser.sanitizeFilename(media.title);

    if (option.kind == MediaKind.photo) {
      final urls = option.photoUrls.isNotEmpty ? option.photoUrls : media.photos;
      if (urls.isEmpty) throw StateError('No photos on this post');
      if (!await gallery.ensureAccess(images: true)) {
        throw StateError('Gallery permission is needed to save.');
      }
      final files = <File>[
        for (final path in resumePaths.take(completedPhotos.clamp(0, urls.length)))
          if (path.isNotEmpty && File(path).existsSync()) File(path),
      ];
      var start = files.length;
      if (resumePaths.length > files.length) {
        final partial = File(resumePaths[files.length]);
        if (partial.existsSync()) {
          files.add(partial);
          start = files.length - 1;
        }
      }
      for (var i = start; i < urls.length; i++) {
        final ext = _extOf(urls[i], fallback: 'jpg');
        final dest = i < files.length ? files[i] : File(p.join(folder.path, '$base-${i + 1}.$ext'));
        dest.parent.createSync(recursive: true);
        try {
          final file = _matchExtension(await net.save(
            urls[i],
            dest,
            referer: extractor.refererFor(urls[i]),
            onProgress: (value) {
              final slice = 1 / urls.length;
              onProgress((i * slice) + (value * slice * 0.9));
            },
          ));
          await gallery.saveFile(file, image: !isVideoFile(file));
          if (i < files.length) {
            files[i] = file;
          } else {
            files.add(file);
          }
          onProgress((i + 1) / urls.length);
        } on PausedException {
          throw PausedException(
            paths: [
              for (final file in files) file.path,
              if (dest.existsSync() && (files.isEmpty || files.last.path != dest.path)) dest.path,
            ],
            completed: files.length,
          );
        } on CancelledException {
          _deleteAll([...files, dest]);
          rethrow;
        }
      }
      return DownloadResult(files: files, photoCount: files.length);
    }

    final url = option.directUrl;
    if (url == null || url.isEmpty) {
      throw StateError('Could not download this. Try again.');
    }
    final isAudio = option.kind == MediaKind.audio;
    final ext = option.ext.isEmpty ? 'mp4' : option.ext;
    final dest = resumePaths.isNotEmpty
        ? File(resumePaths.first)
        : _unique(folder, isAudio ? '$base-source' : base, ext);
    dest.parent.createSync(recursive: true);
    File file;
    try {
      file = await net.save(
        url,
        dest,
        referer: extractor.refererFor(url),
        onProgress: (value) => onProgress(value * 0.88),
      );
    } on PausedException {
      throw PausedException(
        paths: dest.existsSync() ? [dest.path] : const [],
      );
    } on CancelledException {
      _deleteAll([dest]);
      rethrow;
    }
    onProgress(0.9);
    try {
      if (isAudio) {
        file = await _toMp3(file, _unique(folder, base, 'mp3'));
        onProgress(0.93);
        file = await _tagAudio(file, media);
      }
      onProgress(0.95);
      if (!await gallery.ensureAccess(images: option.kind != MediaKind.video)) {
        throw StateError('Gallery permission is needed to save.');
      }
      if (isAudio) {
        await gallery.saveAudio(file);
      } else {
        await gallery.saveFile(file, image: false);
      }
    } on PausedException {
      throw PausedException(paths: [file.path]);
    } on CancelledException {
      _deleteAll([file]);
      rethrow;
    }
    onProgress(1);
    return DownloadResult(files: [file], photoCount: 0);
  }

  void _deleteAll(Iterable<File> files) {
    for (final file in files) {
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
  }

  Future<File> _toMp3(File source, File target) async {
    if (AudioConverter.isMp3(source)) return source.renameSync(target.path);
    try {
      return await converter.toMp3(source, target);
    } finally {
      _deleteAll([source]);
    }
  }

  Future<File> _tagAudio(File audio, MediaInfo media) async {
    File? cover;
    try {
      cover = await _coverFile(media);
      LyricsHit? lyrics;
      try {
        lyrics = await LyricsClient((uri) async {
          return net.get(
            uri.toString(),
            headers: {'Accept': 'application/json'},
            userAgent: NetHints.desktopUa,
          );
        }).find(media.title, media.author, media.duration);
      } catch (_) {}
      final tagged = await DownloadHost.tagAudio(
        path: audio.path,
        title: media.title,
        author: media.author,
        coverPath: cover?.path,
        lyricsPlain: lyrics?.plain,
        lyricsSynced: lyrics?.synced,
      );
      if (tagged != null && tagged.isNotEmpty) {
        final file = File(tagged);
        if (file.existsSync()) return file;
      }
    } on PausedException {
      rethrow;
    } on CancelledException {
      rethrow;
    } catch (_) {
    } finally {
      if (cover != null && cover.existsSync()) {
        try {
          cover.deleteSync();
        } catch (_) {}
      }
    }
    return audio;
  }

  Future<File?> _coverFile(MediaInfo media) async {
    final urls = <String>[
      if (media.thumbnail != null && media.thumbnail!.startsWith('http')) media.thumbnail!,
      ..._youtubeCovers(media.webpageUrl),
    ];
    if (urls.isEmpty) return null;
    final folder = Directory(p.join((await getTemporaryDirectory()).path, 'covers'));
    await folder.create(recursive: true);
    for (final url in urls) {
      try {
        final dest = File(p.join(folder.path, 'cover-${media.id}.jpg'));
        final file = await net.save(
          url,
          dest,
          referer: extractor.refererFor(url),
        );
        if (file.existsSync() && file.lengthSync() >= 400) return file;
      } catch (_) {}
    }
    return null;
  }

  List<String> _youtubeCovers(String pageUrl) {
    final id = LinkParser.youtubeId(pageUrl);
    if (id == null) return const [];
    return [
      'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      'https://i.ytimg.com/vi/$id/sddefault.jpg',
      'https://i.ytimg.com/vi/$id/mqdefault.jpg',
      'https://i.ytimg.com/vi/$id/maxresdefault.jpg',
    ];
  }

  File _unique(Directory folder, String base, String ext) {
    var index = 0;
    while (true) {
      final name = index == 0 ? '$base.$ext' : '$base-$index.$ext';
      final file = File(p.join(folder.path, name));
      if (!file.existsSync()) return file;
      index += 1;
    }
  }

  String _extOf(String url, {required String fallback}) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    for (final ext in ['jpg', 'jpeg', 'png', 'webp', 'heic', 'mp4']) {
      if (path.endsWith('.$ext') || path.contains('.$ext?')) return ext == 'jpeg' ? 'jpg' : ext;
    }
    return fallback;
  }

  /// Album items can be photos or videos; trust the bytes over the URL.
  File _matchExtension(File file) {
    final ext = sniffExtension(file);
    if (ext == null || p.extension(file.path).toLowerCase() == '.$ext') return file;
    final target = File(p.setExtension(file.path, '.$ext'));
    try {
      if (target.existsSync()) target.deleteSync();
      return file.renameSync(target.path);
    } catch (_) {
      return file;
    }
  }
}

bool isVideoFile(File file) => sniffExtension(file) == 'mp4' || p.extension(file.path).toLowerCase() == '.mp4';

String? sniffExtension(File file) {
  try {
    final raf = file.openSync();
    final head = raf.readSync(12);
    raf.closeSync();
    if (head.length < 12) return null;
    final box = String.fromCharCodes(head.sublist(4, 8));
    if (box == 'ftyp') {
      final brand = String.fromCharCodes(head.sublist(8, 12));
      if (const {'heic', 'heix', 'mif1', 'msf1', 'avif'}.contains(brand)) return brand == 'avif' ? 'avif' : 'heic';
      if (brand.startsWith('M4A')) return 'm4a';
      return 'mp4';
    }
    if (head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF) return 'jpg';
    if (head[0] == 0x89 && head[1] == 0x50 && head[2] == 0x4E && head[3] == 0x47) return 'png';
    if (String.fromCharCodes(head.sublist(0, 4)) == 'RIFF' && String.fromCharCodes(head.sublist(8, 12)) == 'WEBP') {
      return 'webp';
    }
    return null;
  } catch (_) {
    return null;
  }
}
