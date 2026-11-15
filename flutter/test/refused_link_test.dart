import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/data/clients/youtube_client.dart';
import 'package:nazzil/data/downloader.dart';
import 'package:nazzil/data/extractor.dart';
import 'package:nazzil/data/gallery.dart';
import 'package:nazzil/data/net.dart';
import 'package:nazzil/models/media.dart';
import 'package:nazzil/state/nazzil_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

late Directory scratch;

/// A googlevideo link as YouTube hands it to the app client [client].
String youtubeLink(String client, {int itag = 140}) =>
    'https://rr3---sn-4g5e6nsz.googlevideo.com/videoplayback?expire=1&itag=$itag&c=$client';

QualityOption audioOption(String link) =>
    QualityOption(id: 'yt-audio', label: 'Audio', ext: 'm4a', kind: MediaKind.audio, directUrl: link);

String clientsOf(Iterable<String> links) => [for (final link in links) Uri.parse(link).queryParameters['c']].join(' ');

/// Each lookup answers with the link [next] gives for the clients refused so far.
class _Extractor extends MediaExtractor {
  _Extractor(this.next);

  /// Hands out links from the first of [clients] not yet refused, and fails once all are.
  _Extractor.youtube(List<String> clients)
      : next = ((refused) => youtubeLink(
              clients.firstWhere((c) => !refused.contains(c), orElse: () => throw StateError('No downloadable YouTube video')),
            ));

  final String Function(Set<String> refused) next;
  final asked = <Set<String>>[];

  @override
  Future<MediaInfo> fetch(String rawUrl, {Set<String> refused = const {}}) async {
    asked.add({...refused});
    return MediaInfo(
      id: 'VJGaVkDpWr4',
      title: 'glitter',
      webpageUrl: rawUrl,
      platform: PlatformId.youtube,
      options: [audioOption(next(refused))],
    );
  }
}

/// Answers the links [refuses] picks with a 403, as googlevideo does, and saves the others.
class _Downloader extends MediaDownloader {
  _Downloader(MediaExtractor extractor, this.refuses)
      : super(extractor: extractor, gallery: GalleryService(), net: NetClient());
  final bool Function(Uri link) refuses;
  final tried = <String>[];

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
    final link = Uri.parse(option.directUrl!);
    tried.add(option.directUrl!);
    if (refuses(link)) throw HttpException('This post blocked the download. Try again.', uri: link);
    return DownloadResult(files: [File('${scratch.path}/glitter.mp3')..writeAsBytesSync([1, 2, 3])], photoCount: 0);
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

LibraryItem songItem(QualityOption option, {String status = LibraryItem.statusQueued, List<String> paths = const []}) =>
    LibraryItem(
      id: 'q-yt:VJGaVkDpWr4-Audio',
      title: 'glitter',
      platform: PlatformId.youtube,
      kind: option.kind,
      quality: option.label,
      createdAt: DateTime.now(),
      sourceUrl: 'https://www.youtube.com/watch?v=VJGaVkDpWr4',
      videoKey: 'yt:VJGaVkDpWr4',
      paths: paths,
      status: status,
      option: option,
    );

/// A controller whose library holds just [item]; a queued one starts at once.
Future<NazzilController> withLibrary(LibraryItem item, MediaExtractor extractor, MediaDownloader downloader) async {
  SharedPreferences.setMockInitialValues({
    'nazzil.library.v2': jsonEncode([item.toJson()]),
  });
  final controller = NazzilController(extractor: extractor, downloader: downloader);
  addTearDown(controller.dispose);
  await until(controller, () => controller.library.isNotEmpty);
  return controller;
}

Future<LibraryItem> settled(NazzilController controller) async {
  await until(controller, () => !controller.library.single.active && !controller.downloading);
  return controller.library.single;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    scratch = Directory.systemTemp.createTempSync('nazzil-refused');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => scratch.path,
    );
    PackageInfo.setMockInitialValues(
      appName: 'Nazzil',
      packageName: 'com.nazzil.nazzil',
      version: '2.5.0',
      buildNumber: '28',
      buildSignature: '',
    );
  });

  tearDownAll(() => scratch.deleteSync(recursive: true));

  test('only a googlevideo link names the YouTube app client it was given to', () {
    expect(YouTubeClient.clientOf(Uri.parse(youtubeLink('ANDROID_VR'))), 'ANDROID_VR');
    expect(YouTubeClient.clientOf(Uri.parse('https://v16m.tiktokcdn.com/video/tos/song?c=3')), isNull);
    expect(YouTubeClient.clientOf(null), isNull);
  });

  test('a song YouTube refuses through one app client comes down through the next', () async {
    final extractor = _Extractor.youtube(['ANDROID', 'ANDROID_VR', 'IOS']);
    final downloader = _Downloader(extractor, (link) => {'ANDROID', 'ANDROID_VR'}.contains(link.queryParameters['c']));
    final controller = await withLibrary(songItem(audioOption(youtubeLink('ANDROID'))), extractor, downloader);
    final item = await settled(controller);
    expect(item.status, LibraryItem.statusDone);
    expect(clientsOf(downloader.tried), 'ANDROID ANDROID_VR IOS');
    expect(extractor.asked, [
      {'ANDROID'},
      {'ANDROID', 'ANDROID_VR'},
    ]);
  });

  test('a song every app client is refused for fails as blocked, after each one is tried', () async {
    final extractor = _Extractor.youtube(['ANDROID', 'ANDROID_VR', 'IOS']);
    final downloader = _Downloader(extractor, (_) => true);
    final controller = await withLibrary(songItem(audioOption(youtubeLink('ANDROID'))), extractor, downloader);
    final item = await settled(controller);
    expect(item.status, LibraryItem.statusFailed);
    expect(item.error, Failure.blocked.name);
    expect(downloader.tried.map((link) => Uri.parse(link).queryParameters['c']).toSet(), {'ANDROID', 'ANDROID_VR', 'IOS'});
    expect(extractor.asked.last, {'ANDROID', 'ANDROID_VR', 'IOS'});
  });

  test("another site's refused link is asked for once more, whatever its query holds", () async {
    final extractor = _Extractor((_) => 'https://v16m.tiktokcdn.com/video/tos/song?c=${DateTime.now().microsecondsSinceEpoch}');
    final downloader = _Downloader(extractor, (_) => true);
    final controller = await withLibrary(songItem(audioOption(extractor.next(const {}))), extractor, downloader);
    final item = await settled(controller);
    expect(item.status, LibraryItem.statusFailed);
    expect(downloader.tried.toSet(), hasLength(2), reason: 'the second try is on the new link');
    expect(extractor.asked, hasLength(1));
  });
}
