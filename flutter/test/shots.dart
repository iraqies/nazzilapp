// A screenshot harness, not a test. A bare `flutter test` skips it (no _test suffix);
// run it on purpose with `flutter test test/shots.dart` to render the screens to PNGs
// under $NAZZIL_SHOTS (default /home/ubuntu/nazzil-shots), for showing the owner the look.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/app.dart';
import 'package:nazzil/data/link_parser.dart';
import 'package:nazzil/models/media.dart';
import 'package:nazzil/state/nazzil_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pictures.dart';
import 'support/typefaces.dart';

late Directory scratch;
final String out = Platform.environment['NAZZIL_SHOTS'] ?? '/home/ubuntu/nazzil-shots';

Future<void> loadIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/home/ubuntu/flutter-sdk';
  final file = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!file.existsSync()) return;
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())))).load();
}

Future<String> solid(WidgetTester tester, String name, int w, int h, Color color) async {
  final path = '${scratch.path}/$name.png';
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = color);
    final image = await recorder.endRecording().toImage(w, h);
    File(path).writeAsBytesSync((await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
    image.dispose();
  });
  return path;
}

Future<void> settle(WidgetTester tester) async {
  final cache = PaintingBinding.instance.imageCache;
  var turns = 0;
  do {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 120));
    turns++;
  } while (turns < 4 || cache.pendingImageCount > 0);
  await tester.pumpAndSettle();
}

Future<NazzilController> boot(
  WidgetTester tester, {
  String language = 'en',
  String theme = 'dark',
  List<LibraryItem> library = const [],
  Size size = const Size(390, 844),
  double statusBar = 47,
  double pixelRatio = 3,
}) async {
  SharedPreferences.setMockInitialValues({
    'nazzil.language': language,
    'nazzil.theme.v2': theme,
    'nazzil.library.v2': jsonEncode([for (final item in library) item.toJson()]),
  });
  PackageInfo.setMockInitialValues(
    appName: 'Nazzil',
    packageName: 'com.nazzil.nazzil',
    version: '2.4.0',
    buildNumber: '27',
    buildSignature: '',
  );
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  tester.view.padding = FakeViewPadding(top: statusBar * pixelRatio);
  tester.view.viewPadding = FakeViewPadding(top: statusBar * pixelRatio);
  addTearDown(tester.view.reset);
  final controller = NazzilController();
  await tester.pumpWidget(NazzilApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> shoot(WidgetTester tester, String name) async {
  final view = tester.binding.renderViews.first;
  // ignore: invalid_use_of_protected_member
  final layer = view.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final image = await layer.toImage(view.paintBounds);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    image.dispose();
  });
}

MediaInfo pictured(String thumb) => MediaInfo(
      id: 'abc',
      title: 'Big Buck Bunny — the full open movie from the Blender Foundation',
      author: 'Blender Foundation',
      webpageUrl: 'https://www.youtube.com/watch?v=abc',
      platform: PlatformId.youtube,
      duration: 596,
      thumbnail: thumb,
      options: const [
        QualityOption(id: 'hd', label: 'HD', ext: 'mp4', kind: MediaKind.video, directUrl: 'https://example.com/hd'),
        QualityOption(id: 'sd', label: 'SD', ext: 'mp4', kind: MediaKind.video, directUrl: 'https://example.com/sd'),
        QualityOption(id: 'audio', label: 'Audio', ext: 'mp3', kind: MediaKind.audio, directUrl: 'https://example.com/a'),
      ],
    );

LibraryItem downloadingJob(MediaInfo media) => LibraryItem(
      id: 'job',
      title: media.title,
      platform: media.platform,
      kind: MediaKind.video,
      quality: 'HD',
      createdAt: DateTime(2026, 11, 10),
      sourceUrl: media.webpageUrl,
      videoKey: LinkParser.identityKey(media.webpageUrl, media.id),
      thumbnail: media.thumbnail,
      status: LibraryItem.statusDownloading,
    );

LibraryItem saved(String id, PlatformId platform, MediaKind kind, String title, String thumb, {int photoCount = 0}) {
  final path = '${scratch.path}/$id.${kind == MediaKind.photo ? 'jpg' : 'mp4'}';
  File(path).writeAsBytesSync([0]);
  return LibraryItem(
    id: id,
    title: title,
    platform: platform,
    kind: kind,
    quality: 'HD',
    createdAt: DateTime(2026, 11, 10),
    sourceUrl: 'https://example.com/$id',
    videoKey: '${platform.name}:$id',
    paths: [path],
    photoCount: photoCount,
    thumbnail: thumb,
    status: LibraryItem.statusDone,
  );
}

void main() {
  setUpAll(() async {
    scratch = Directory.systemTemp.createTempSync('nazzil-shots');
    Directory(out).createSync(recursive: true);
    await loadShippedTypefaces();
    await loadIcons();
  });

  Future<List<LibraryItem>> shelf(WidgetTester tester) async {
    final colours = [
      const Color(0xFF4C6EF5),
      const Color(0xFFE8590C),
      const Color(0xFF2F9E44),
      const Color(0xFFE64980),
      const Color(0xFF7048E8),
      const Color(0xFF1098AD),
    ];
    final thumbs = [for (var i = 0; i < colours.length; i++) await solid(tester, 'thumb$i', 400, 300, colours[i])];
    return [
      saved('v1', PlatformId.youtube, MediaKind.video, 'Big Buck Bunny — the full open movie', thumbs[0]),
      saved('v2', PlatformId.tiktok, MediaKind.video, 'Street food in Osaka at midnight', thumbs[1]),
      saved('p1', PlatformId.instagram, MediaKind.photo, 'Weekend in the mountains', thumbs[2], photoCount: 5),
      saved('v3', PlatformId.youtube, MediaKind.video, 'How aqueducts actually worked', thumbs[3]),
      saved('v4', PlatformId.facebook, MediaKind.video, 'Grandma reacts to the news', thumbs[4]),
      saved('p2', PlatformId.pinterest, MediaKind.photo, 'Kitchen ideas', thumbs[5]),
    ];
  }

  for (final theme in ['dark', 'light']) {
    testWidgets('home empty en $theme', (tester) async {
      await boot(tester, theme: theme);
      await shoot(tester, 'home-empty-en-$theme');
    });

    testWidgets('result en $theme', (tester) async {
      final thumb = await solid(tester, 'poster', 400, 225, const Color(0xFF3B5BDB));
      LocalPictures.serve({thumb: thumb});
      final controller = await boot(tester, theme: theme);
      controller
        ..media = pictured(thumb)
        ..selected = pictured(thumb).options.first
        ..notifyListeners();
      await tester.pump();
      await settle(tester);
      await shoot(tester, 'result-en-$theme');
    });

    testWidgets('downloading en $theme', (tester) async {
      final thumb = await solid(tester, 'poster', 400, 225, const Color(0xFF3B5BDB));
      LocalPictures.serve({thumb: thumb});
      final media = pictured(thumb);
      final controller = await boot(tester, theme: theme);
      controller
        ..media = media
        ..selected = media.options.first
        ..notifyListeners();
      await tester.pump();
      // Settle loads the poster and lets the boot-time download pump finish; its
      // cleanup clears activeJobId, so the running state has to be set after it.
      await settle(tester);
      controller
        ..library = [downloadingJob(media)]
        ..activeJobId = 'job'
        ..downloading = true
        ..progress = 0.5
        ..notifyListeners();
      await tester.pumpAndSettle();
      await shoot(tester, 'downloading-en-$theme');
    });

    testWidgets('library en $theme', (tester) async {
      final items = await shelf(tester);
      LocalPictures.serve({for (final i in items) if (i.thumbnail != null) i.thumbnail!: i.thumbnail!});
      final controller = await boot(tester, theme: theme, library: items);
      controller.goTab(1);
      await tester.pump();
      await settle(tester);
      await shoot(tester, 'library-en-$theme');
    });

    testWidgets('settings en $theme', (tester) async {
      await boot(tester, theme: theme);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await shoot(tester, 'settings-en-$theme');
    });
  }

  testWidgets('home empty ar dark', (tester) async {
    await boot(tester, language: 'ar', theme: 'dark');
    await shoot(tester, 'home-empty-ar-dark');
  });

  testWidgets('settings ar dark', (tester) async {
    await boot(tester, language: 'ar', theme: 'dark');
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await shoot(tester, 'settings-ar-dark');
  });

  testWidgets('library ar dark', (tester) async {
    final items = await shelf(tester);
    LocalPictures.serve({for (final i in items) if (i.thumbnail != null) i.thumbnail!: i.thumbnail!});
    final controller = await boot(tester, language: 'ar', theme: 'dark', library: items);
    controller.goTab(1);
    await tester.pump();
    await settle(tester);
    await shoot(tester, 'library-ar-dark');
  });
}
