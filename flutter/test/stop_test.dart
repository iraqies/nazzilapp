import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/data/downloader.dart';
import 'package:nazzil/data/extractor.dart';
import 'package:nazzil/data/gallery.dart';
import 'package:nazzil/data/media_convert.dart';
import 'package:nazzil/data/net.dart';
import 'package:nazzil/models/media.dart';
import 'package:nazzil/state/nazzil_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

late HttpServer server;
late Directory scratch;

String at(String path) => 'http://127.0.0.1:${server.port}/$path';

/// Records what would have gone to the gallery or to Downloads.
class _Gallery extends GalleryService {
  final saved = <String>[];

  @override
  Future<bool> ensureAccess({required bool images}) async => true;

  @override
  Future<void> saveFile(File file, {required bool image}) async => saved.add(file.path);

  @override
  Future<void> saveAudio(File file) async => saved.add(file.path);
}

/// Stands in for ffmpeg: it waits at the gate, then writes the output.
class _Converter extends MediaConverter {
  final started = Completer<void>();
  final gate = Completer<void>();

  @override
  Future<File> join(File video, File audio, File output) async {
    started.complete();
    await gate.future;
    return output..writeAsBytesSync(List.filled(2048, 1));
  }
}

/// Holds the link lookup open until the test lets it through.
class _Extractor extends MediaExtractor {
  _Extractor(this.answer);
  final MediaInfo answer;
  final entered = Completer<void>();
  final gate = Completer<void>();

  @override
  Future<MediaInfo> fetch(String rawUrl) async {
    if (!entered.isCompleted) entered.complete();
    await gate.future;
    return answer;
  }
}

/// Counts the downloads that get as far as moving bytes, and holds each open.
class _Downloader extends MediaDownloader {
  _Downloader(MediaExtractor extractor) : super(extractor: extractor, gallery: _Gallery(), net: NetClient());
  int runs = 0;
  final entered = Completer<void>();
  final gate = Completer<void>();

  @override
  Future<DownloadResult> download({
    required MediaInfo media,
    required QualityOption option,
    required void Function(double progress) onProgress,
    void Function()? onConvert,
    List<String> resumePaths = const [],
    int completedPhotos = 0,
    int? generation,
  }) async {
    runs += 1;
    if (!entered.isCompleted) entered.complete();
    await gate.future;
    return DownloadResult(files: [for (final path in resumePaths) File(path)], photoCount: 0);
  }

  @override
  Future<void> sweep(Iterable<LibraryItem> items) async {}
}

Future<void> until(NazzilController controller, bool Function() ready) {
  if (ready()) return Future.value();
  final done = Completer<void>();
  void check() {
    if (!ready() || done.isCompleted) return;
    controller.removeListener(check);
    done.complete();
  }

  controller.addListener(check);
  return done.future.timeout(const Duration(seconds: 5));
}

/// A controller whose library holds one paused download with a part of its file on disk.
Future<({NazzilController controller, _Extractor extractor, _Downloader downloader, File partial})> pausedJob(
  String id,
) async {
  final partial = File('${scratch.path}/$id.mp4')..writeAsBytesSync(List.filled(1000, 1));
  final option = QualityOption(id: 'hd', label: 'HD', ext: 'mp4', kind: MediaKind.video, directUrl: at('video'));
  final paused = LibraryItem(
    id: 'q-yt:$id-HD',
    title: 'Clip $id',
    platform: PlatformId.youtube,
    kind: MediaKind.video,
    quality: 'HD',
    createdAt: DateTime.now(),
    sourceUrl: 'https://example.com/$id',
    videoKey: 'yt:$id',
    paths: [partial.path],
    status: LibraryItem.statusPaused,
    option: option,
  );
  SharedPreferences.setMockInitialValues({
    'nazzil.library.v2': jsonEncode([paused.toJson()]),
  });
  final extractor = _Extractor(
    MediaInfo(
      id: id,
      title: paused.title,
      webpageUrl: paused.sourceUrl,
      platform: PlatformId.youtube,
      options: [option],
    ),
  );
  final downloader = _Downloader(extractor);
  final controller = NazzilController(extractor: extractor, downloader: downloader);
  addTearDown(controller.dispose);
  await until(controller, () => controller.library.isNotEmpty);
  return (controller: controller, extractor: extractor, downloader: downloader, partial: partial);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The test binding answers every request with 400; these tests talk to a real local server.
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType('video', 'mp4');
      request.response.add(List.filled(4096, 7));
      await request.response.close();
    });
    scratch = Directory.systemTemp.createTempSync('nazzil-stop');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => scratch.path,
    );
    PackageInfo.setMockInitialValues(
      appName: 'Nazzil',
      packageName: 'com.nazzil.nazzil',
      version: '1.3.0',
      buildNumber: '22',
      buildSignature: '',
    );
  });

  tearDownAll(() async {
    await server.close(force: true);
    scratch.deleteSync(recursive: true);
  });

  test('a stop pressed before a job reaches its first file still lands', () async {
    final net = NetClient();
    addTearDown(net.close);
    final dest = File('${scratch.path}/first.mp4');

    var mark = net.generation;
    net.cancel();
    expect(net.cancelledSince(mark), isTrue);
    await expectLater(
      net.save(at('first'), dest, referer: '', generation: mark),
      throwsA(isA<CancelledException>()),
    );
    expect(dest.existsSync(), isFalse);

    mark = net.generation;
    net.pause();
    expect(net.cancelledSince(mark), isFalse, reason: 'a pause is not a cancel');
    await expectLater(
      net.save(at('first'), dest, referer: '', generation: mark),
      throwsA(isA<PausedException>()),
    );

    // Read after the stop, the mark is clean and the file comes down.
    mark = net.generation;
    final file = await net.save(at('first'), dest, referer: '', generation: mark);
    expect(file.lengthSync(), 4096);
    expect(net.cancelledSince(mark), isFalse);
  });

  test('a cancel pressed while the file is put together keeps it out of the gallery', () async {
    Future<({_Gallery gallery, _Converter converter, NetClient net, Future<DownloadResult> job})> start(String id) async {
      final gallery = _Gallery();
      final converter = _Converter();
      final net = NetClient();
      addTearDown(net.close);
      final downloader = MediaDownloader(extractor: MediaExtractor(), gallery: gallery, net: net, converter: converter);
      final job = downloader.download(
        media: MediaInfo(
          id: id,
          title: 'Joined $id',
          webpageUrl: 'https://example.com/$id',
          platform: PlatformId.youtube,
          options: const [],
        ),
        option: QualityOption(
          id: 'hd',
          label: 'HD',
          ext: 'mp4',
          kind: MediaKind.video,
          directUrl: at('video'),
          audioUrl: at('audio'),
        ),
        onProgress: (_) {},
      );
      return (gallery: gallery, converter: converter, net: net, job: job);
    }

    List<String> onDisk() => [
          for (final entry in Directory('${scratch.path}/media').listSync()) entry.uri.pathSegments.last,
        ];

    final kept = await start('kept');
    await kept.converter.started.future;
    kept.converter.gate.complete();
    final result = await kept.job;
    expect(kept.gallery.saved, [result.files.single.path]);
    expect(onDisk(), ['Joined kept.mp4']);

    final dropped = await start('dropped');
    final outcome = expectLater(dropped.job, throwsA(isA<CancelledException>()));
    await dropped.converter.started.future;
    dropped.net.cancel();
    dropped.converter.gate.complete();
    await outcome;
    expect(dropped.gallery.saved, isEmpty);
    expect(onDisk(), ['Joined kept.mp4'], reason: 'nothing of the cancelled job is left behind');
  });

  test('a resumed download says Downloading, not Waiting, once its links are refreshed', () async {
    final job = await pausedJob('resume');
    await job.controller.resumeJob(job.controller.library.single);
    job.extractor.gate.complete();
    await job.downloader.entered.future;
    expect(job.controller.library.single.status, LibraryItem.statusDownloading);
    expect(job.controller.queuedCount, 0);
    job.downloader.gate.complete();
    await until(job.controller, () => !job.controller.downloading);
    expect(job.controller.library.single.status, LibraryItem.statusDone);
    expect(job.downloader.runs, 1);
  });

  test('a resumed download cancelled while its links are refreshed stays cancelled', () async {
    final job = await pausedJob('cancel');
    await job.controller.resumeJob(job.controller.library.single);
    await job.extractor.entered.future;
    expect(job.controller.activeJobId, job.controller.library.single.id);
    await job.controller.cancelCurrent();
    job.extractor.gate.complete();
    await until(job.controller, () => !job.controller.downloading);
    expect(job.controller.library.single.status, LibraryItem.statusCancelled);
    expect(job.downloader.runs, 0, reason: 'no bytes are asked for after Cancel');
    expect(job.partial.existsSync(), isFalse);
  });

  test('a resumed download paused while its links are refreshed keeps what it had', () async {
    final job = await pausedJob('pause');
    await job.controller.resumeJob(job.controller.library.single);
    await job.extractor.entered.future;
    await job.controller.pauseCurrent();
    job.extractor.gate.complete();
    await until(job.controller, () => !job.controller.downloading);
    final item = job.controller.library.single;
    expect(item.status, LibraryItem.statusPaused);
    expect(item.paths, [job.partial.path]);
    expect(job.downloader.runs, 0);
    expect(job.partial.existsSync(), isTrue);
  });
}
