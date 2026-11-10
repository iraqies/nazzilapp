import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/data/downloader.dart';
import 'package:nazzil/data/extractor.dart';
import 'package:nazzil/data/gallery.dart';
import 'package:nazzil/data/net.dart';
import 'package:nazzil/models/media.dart';
import 'package:nazzil/state/nazzil_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

late HttpServer server;
late Directory scratch;

String at(String name) => 'http://127.0.0.1:${server.port}/$name';

/// The start of a JPEG, then [length] bytes of [fill]: enough to tell photos apart.
List<int> jpeg(int fill, int length) => [0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(length, fill)];

final bodies = <String, List<int>>{
  'one.jpg': jpeg(1, 2000),
  'two.jpg': jpeg(2, 3000),
  'three.jpg': jpeg(3, 4000),
  // Named like a JPEG by its site, a PNG by its bytes.
  'disguised.jpg': [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ...List.filled(1500, 9)],
};

/// Records the bytes that would have gone to the gallery or to Downloads.
class _Gallery extends GalleryService {
  final saved = <List<int>>[];

  @override
  Future<bool> ensureAccess({required bool images}) async => true;

  @override
  Future<void> saveFile(File file, {required bool image}) async => saved.add(file.readAsBytesSync());
}

QualityOption photosOf(List<String> names, {String id = 'photos', String label = 'Photos'}) => QualityOption(
      id: id,
      label: label,
      ext: 'jpg',
      kind: MediaKind.photo,
      photoUrls: [for (final name in names) at(name)],
    );

MediaInfo post(String id, String title, QualityOption option) => MediaInfo(
      id: id,
      title: title,
      webpageUrl: 'https://www.reddit.com/comments/$id',
      platform: PlatformId.reddit,
      photos: option.photoUrls,
      options: [option],
    );

void main() {
  late _Gallery gallery;
  late MediaDownloader downloader;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The test binding answers every request with 400; these tests talk to a real local server.
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    // Like the photo sites, it sends the rest of a file when asked for a range.
    server.listen((request) async {
      final body = bodies[request.uri.pathSegments.last]!;
      final range = RegExp(r'bytes=(\d+)-').firstMatch(request.headers.value('range') ?? '');
      final from = range == null ? 0 : int.parse(range.group(1)!);
      final response = request.response;
      response.headers.contentType = ContentType('image', 'jpeg');
      if (from >= body.length) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      } else {
        if (range != null) response.statusCode = HttpStatus.partialContent;
        response.add(body.sublist(from));
      }
      await response.close();
    });
    PackageInfo.setMockInitialValues(
      appName: 'Nazzil',
      packageName: 'com.nazzil.nazzil',
      version: '1.3.0',
      buildNumber: '22',
      buildSignature: '',
    );
  });

  tearDownAll(() => server.close(force: true));

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('nazzil-photos');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => scratch.path,
    );
    gallery = _Gallery();
    final net = NetClient();
    addTearDown(net.close);
    downloader = MediaDownloader(extractor: MediaExtractor(), gallery: gallery, net: net);
  });

  tearDown(() => scratch.deleteSync(recursive: true));

  test('one photo saved out of an album is that photo, and the album keeps its own', () async {
    final album = photosOf(['one.jpg', 'two.jpg', 'three.jpg']);
    final media = post('alb', 'Weekend in Erbil', album);
    final all = await downloader.download(media: media, option: album, onProgress: (_) {});
    expect([for (final file in all.files) file.readAsBytesSync()], [bodies['one.jpg'], bodies['two.jpg'], bodies['three.jpg']]);

    final third = await downloader.download(
      media: media,
      option: photosOf(['three.jpg'], id: 'photo-2', label: 'Photo'),
      onProgress: (_) {},
    );
    expect(all.files.map((file) => file.path), isNot(contains(third.files.single.path)));
    expect(third.files.single.readAsBytesSync(), bodies['three.jpg']);
    expect(gallery.saved.last, bodies['three.jpg'], reason: 'the copy for the gallery is the photo that was asked for');
    expect(all.files.first.readAsBytesSync(), bodies['one.jpg'], reason: "the album's first photo is left alone");
  });

  test('two posts with one title each keep their own photo', () async {
    final first = photosOf(['one.jpg']);
    final second = photosOf(['two.jpg']);
    final a = await downloader.download(media: post('a', 'TikTok photos', first), option: first, onProgress: (_) {});
    final b = await downloader.download(media: post('b', 'TikTok photos', second), option: second, onProgress: (_) {});
    expect(a.files.single.path, isNot(b.files.single.path));
    expect(a.files.single.readAsBytesSync(), bodies['one.jpg']);
    expect(b.files.single.readAsBytesSync(), bodies['two.jpg']);
  });

  test('a photo renamed to what its bytes are does not take the place of a file already there', () async {
    final folder = Directory('${scratch.path}/media')..createSync(recursive: true);
    final theirs = File('${folder.path}/Poster.png')..writeAsBytesSync([1, 2, 3]);
    final option = photosOf(['disguised.jpg']);
    final result = await downloader.download(media: post('p', 'Poster', option), option: option, onProgress: (_) {});
    expect(result.files.single.path, endsWith('.png'));
    expect(result.files.single.path, isNot(theirs.path));
    expect(result.files.single.readAsBytesSync(), bodies['disguised.jpg']);
    expect(theirs.readAsBytesSync(), [1, 2, 3]);
  });

  test('deleting one of two entries that share a file leaves the file for the other', () async {
    // Libraries written before photo files had names of their own can hold such a pair.
    final shared = File('${scratch.path}/shared-1.jpg')..writeAsBytesSync(bodies['one.jpg']!);
    final own = File('${scratch.path}/own.jpg')..writeAsBytesSync(bodies['two.jpg']!);
    LibraryItem entry(String quality, List<String> paths) => LibraryItem(
          id: 'q-rd:alb-$quality',
          title: 'Weekend in Erbil',
          platform: PlatformId.reddit,
          kind: MediaKind.photo,
          quality: quality,
          createdAt: DateTime(2026, 11, 10),
          sourceUrl: 'https://www.reddit.com/comments/alb',
          videoKey: 'rd:alb',
          paths: paths,
          photoCount: paths.length,
          status: LibraryItem.statusDone,
        );
    SharedPreferences.setMockInitialValues({
      'nazzil.library.v2': jsonEncode([
        entry('Photo 1', [shared.path]).toJson(),
        entry('Photos', [shared.path, own.path]).toJson(),
      ]),
    });
    final controller = NazzilController(extractor: MediaExtractor(), downloader: downloader);
    addTearDown(controller.dispose);
    for (var turn = 0; turn < 50 && controller.library.length < 2; turn++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(controller.library, hasLength(2));

    await controller.remove(controller.library.firstWhere((item) => item.quality == 'Photo 1'));
    expect(shared.existsSync(), isTrue, reason: 'the album still shows this photo');
    await controller.remove(controller.library.single);
    expect(shared.existsSync(), isFalse);
    expect(own.existsSync(), isFalse);
  });
}
