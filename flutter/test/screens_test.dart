import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/app.dart';
import 'package:nazzil/data/link_parser.dart';
import 'package:nazzil/models/media.dart';
import 'package:nazzil/state/nazzil_controller.dart';
import 'package:nazzil/l10n/strings.dart';
import 'package:nazzil/theme/nazzil_theme.dart';
import 'package:nazzil/ui/screens/viewer_screen.dart';
import 'package:nazzil/ui/widgets/done_sheet.dart';
import 'package:nazzil/ui/widgets/library_tile.dart';
import 'package:nazzil/ui/widgets/title_text.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

late Directory scratch;

LibraryItem entry(
  String id,
  PlatformId platform,
  MediaKind kind, {
  String status = LibraryItem.statusDone,
  String error = '',
  bool onDisk = false,
  int photoCount = 0,
  String? title,
  String? videoKey,
}) {
  final path = '${scratch.path}/$id.${kind == MediaKind.photo ? 'jpg' : 'mp4'}';
  if (onDisk) File(path).writeAsBytesSync([0]);
  return LibraryItem(
    id: id,
    title: title ?? 'Saved item $id',
    platform: platform,
    kind: kind,
    quality: 'HD',
    createdAt: DateTime(2026, 11, 10),
    sourceUrl: 'https://example.com/$id',
    videoKey: videoKey ?? '${platform.name}:$id',
    paths: status == LibraryItem.statusDone ? [path] : const [],
    photoCount: photoCount,
    status: status,
    error: error,
  );
}

Future<NazzilController> boot(
  WidgetTester tester, {
  String language = 'en',
  String theme = 'dark',
  String palette = 'rose',
  List<LibraryItem> library = const [],
  Size size = const Size(360, 720),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({
    'nazzil.language': language,
    'nazzil.theme': theme,
    'nazzil.palette': palette,
    'nazzil.library.v2': jsonEncode([for (final item in library) item.toJson()]),
  });
  PackageInfo.setMockInitialValues(
    appName: 'Nazzil',
    packageName: 'com.nazzil.nazzil',
    version: '1.3.0',
    buildNumber: '22',
    buildSignature: '',
  );
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final controller = NazzilController();
  await tester.pumpWidget(NazzilApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

/// Measures every text and icon on the current page: its own colour against
/// the colour most of the pixels around it have. Lists what misses WCAG AA.
Future<({int checked, double lowest, List<String> faint})> measureContrast(WidgetTester tester) async {
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  late final int width;
  late final int height;
  late final ByteData pixels;
  await tester.runAsync(() async {
    final image = await layer.toImage(view.paintBounds);
    width = image.width;
    height = image.height;
    pixels = (await image.toByteData())!;
    image.dispose();
  });

  var checked = 0;
  var lowest = double.infinity;
  final faint = <String>[];
  // Each widget above a paragraph hands back the same one, so keep a set.
  for (final paragraph in tester.allRenderObjects.whereType<RenderParagraph>().toSet()) {
    final style = paragraph.text.style;
    final own = style?.color;
    final words = paragraph.text.toPlainText().trim();
    if (style == null || own == null || words.isEmpty || !paragraph.hasSize) continue;
    // A page under a sheet or a dialog is dimmed and out of reach.
    final element = (paragraph.debugCreator! as DebugCreator).element;
    if (ModalRoute.of(element)?.isCurrent == false) continue;
    final box = MatrixUtils.transformRect(paragraph.getTransformTo(null), Offset.zero & paragraph.size);
    final left = box.left.floor().clamp(0, width);
    final right = box.right.ceil().clamp(0, width);
    final top = box.top.floor().clamp(0, height);
    final bottom = box.bottom.ceil().clamp(0, height);
    if (left >= right || top >= bottom) continue;

    final counts = <int, int>{};
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final rgba = pixels.getUint32((y * width + x) * 4);
        final near = ((rgba >> 24) - (own.r * 255).round()).abs() <= 16 &&
            ((rgba >> 16 & 0xFF) - (own.g * 255).round()).abs() <= 16 &&
            ((rgba >> 8 & 0xFF) - (own.b * 255).round()).abs() <= 16;
        if (!near) counts[rgba] = (counts[rgba] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) continue;
    final rgba = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final behind = Color.fromARGB(255, rgba >> 24, rgba >> 16 & 0xFF, rgba >> 8 & 0xFF);
    final shown = Color.alphaBlend(own, behind);
    final a = shown.computeLuminance();
    final b = behind.computeLuminance();
    final ratio = (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);

    final icon = style.fontFamily == 'MaterialIcons';
    final size = style.fontSize ?? 14;
    final large = size >= 24 || (size >= 18.66 && (style.fontWeight ?? FontWeight.w400).value >= 700);
    final needed = icon || large ? 3.0 : 4.5;
    checked++;
    if (ratio < lowest) lowest = ratio;
    if (ratio < needed) {
      faint.add('${icon ? 'icon' : '"$words"'} is ${ratio.toStringAsFixed(2)}:1, needs $needed ($own on $behind)');
    }
  }
  return (checked: checked, lowest: lowest, faint: faint);
}

const sampleVideo = MediaInfo(
  id: 'abc',
  title: 'Big Buck Bunny, the full open movie from the Blender Foundation',
  author: 'Blender Foundation',
  webpageUrl: 'https://www.youtube.com/watch?v=abc',
  platform: PlatformId.youtube,
  duration: 596,
  options: [
    QualityOption(id: 'hd', label: 'HD', ext: 'mp4', kind: MediaKind.video, directUrl: 'https://example.com/hd'),
    QualityOption(id: 'sd', label: 'SD', ext: 'mp4', kind: MediaKind.video, directUrl: 'https://example.com/sd'),
    QualityOption(id: 'audio', label: 'Audio', ext: 'mp3', kind: MediaKind.audio, directUrl: 'https://example.com/a'),
  ],
);

void main() {
  setUp(() {
    scratch = Directory.systemTemp.createTempSync('nazzil-screens');
    // The image cache asks the platform for a folder; tests have no platform.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => scratch.path,
    );
  });
  tearDown(() => scratch.deleteSync(recursive: true));

  setUpAll(() async {
    for (final (family, file) in [
      ('Outfit', 'assets/fonts/Outfit.ttf'),
      ('NotoNaskhArabic', 'assets/fonts/NotoNaskhArabic.ttf'),
    ]) {
      final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(File(file).readAsBytesSync())));
      await loader.load();
    }
  });

  testWidgets('home: empty fetch explains itself and icon buttons carry names', (tester) async {
    final controller = await boot(tester);
    expect(find.text('Download the video. Keep it.'), findsOneWidget);
    expect(find.text('Link'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_outward_rounded), findsNothing);
    expect(find.text('Three beats'), findsNothing);

    await tester.tap(find.text('Fetch'));
    await tester.pumpAndSettle();
    expect(find.text('Paste a link first.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'https://example.com/nothing');
    await tester.pumpAndSettle();
    expect(find.text('Paste a link first.'), findsNothing);
    await tester.tap(find.text('Fetch'));
    await tester.pumpAndSettle();
    expect(find.text('This link is not from a supported app yet.'), findsOneWidget);

    await controller.setLanguage('ar');
    await tester.pumpAndSettle();
    expect(find.text('هذا الرابط مو من تطبيق مدعوم بعد.'), findsOneWidget);
  });

  testWidgets('home result: one platform label, quality icons, ink on the button', (tester) async {
    final controller = await boot(tester, palette: 'emerald', theme: 'light');
    controller
      ..media = sampleVideo
      ..selected = sampleVideo.options.first
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('YouTube · 9:56'), findsOneWidget);
    expect(find.text('YouTube'), findsNothing);
    expect(find.byIcon(Icons.hd_outlined), findsOneWidget);
    expect(find.byIcon(Icons.sd_outlined), findsOneWidget);
    final label = tester.widget<Text>(find.text('Download'));
    final style = DefaultTextStyle.of(tester.element(find.text('Download'))).style.merge(label.style);
    expect(style.color, NazzilColors.ink);

    // One filled button per screen: with a result up, Fetch steps back.
    Color? fill(String text) {
      final button = tester.widget<FilledButton>(
        find.ancestor(of: find.text(text), matching: find.byType(FilledButton)),
      );
      return (button.style ?? FilledButtonTheme.of(tester.element(find.text(text))).style)!
          .backgroundColor!
          .resolve({});
    }

    expect(fill('Download'), NazzilPalette.byId('emerald').fill);
    expect(fill('Fetch'), Theme.of(tester.element(find.text('Fetch'))).colorScheme.surfaceContainerHigh);

    await tester.ensureVisible(find.text('SD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SD'));
    await tester.pumpAndSettle();
    expect(controller.selected?.id, 'sd');
  });

  for (final language in ['en', 'ar']) {
    for (final theme in ['dark', 'light']) {
      testWidgets('nothing overflows at double text size on a 320 wide phone ($language, $theme)', (tester) async {
        final controller = await boot(
          tester,
          language: language,
          theme: theme,
          size: const Size(320, 640),
          textScale: 2,
          library: [
            entry('a', PlatformId.reddit, MediaKind.video, onDisk: true, title: 'A long title that needs both of its lines to show'),
            entry('b', PlatformId.pinterest, MediaKind.photo, onDisk: true, photoCount: 12),
            entry('c', PlatformId.x, MediaKind.audio, status: LibraryItem.statusFailed, error: Failure.network.name),
            entry('d', PlatformId.tiktok, MediaKind.video),
          ],
        );
        // Short steps, so every part of the page gets painted on screen once.
        Future<void> sweep(Type scrollable) async {
          for (var step = 0; step < 16; step++) {
            await tester.drag(find.byType(scrollable), const Offset(0, -240));
            await tester.pump(const Duration(milliseconds: 50));
            expect(tester.takeException(), isNull, reason: '$scrollable step $step');
          }
        }

        controller
          ..clipOffer = 'https://www.tiktok.com/@someone/video/1'
          ..notifyListeners();
        await tester.pump();
        await sweep(CustomScrollView);

        controller
          ..clipOffer = null
          ..media = sampleVideo
          ..selected = sampleVideo.options.first
          ..failure = Failure.blocked
          ..notifyListeners();
        await tester.pump();
        await sweep(CustomScrollView);

        controller.goTab(1);
        await tester.pump();
        await sweep(CustomScrollView);

        await tester.tap(find.byTooltip(controller.s.settings));
        await tester.pump();
        await sweep(ListView);
      });
    }
  }

  testWidgets('settings: language, theme and colour all switch', (tester) async {
    final controller = await boot(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Light'))).brightness, Brightness.light);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Dark'))).brightness, Brightness.dark);

    for (final palette in NazzilPalette.all) {
      final name = controller.s.paletteName(palette.id);
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      expect(controller.settings.palette, palette.id);
      expect(Theme.of(tester.element(find.text(name))).colorScheme.primaryContainer, palette.fill);
    }

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(Directionality.of(tester.element(find.text('العربية'))), TextDirection.rtl);
    expect(find.byTooltip('رجوع'), findsOneWidget);
    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();
    expect(find.text('نزّل الفيديو. خليه عندك.'), findsOneWidget);
  });

  testWidgets('library: counts, names, a filter for every app present, and both empty states', (tester) async {
    final controller = await boot(
      tester,
      library: [
        entry('a', PlatformId.reddit, MediaKind.video, onDisk: true),
        entry('b', PlatformId.pinterest, MediaKind.photo, onDisk: true, photoCount: 3),
        entry('c', PlatformId.x, MediaKind.video, onDisk: true),
      ],
    );
    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('3 photos'), findsOneWidget);
    for (final name in ['Reddit', 'Pinterest', 'X']) {
      expect(find.text(name), findsNWidgets(2), reason: 'a filter chip and a tile label for $name');
    }
    expect(find.text('YouTube'), findsNothing);

    await tester.tap(find.text('Reddit').first);
    await tester.pumpAndSettle();
    expect(find.text('1 item'), findsOneWidget);

    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here for this filter'), findsOneWidget);
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.text('3 items'), findsOneWidget);
    expect(controller.libraryKind, 'all');
    expect(controller.libraryPlatform, 'all');
  });

  testWidgets('library: failed and removed items say why and offer a way forward', (tester) async {
    await boot(
      tester,
      language: 'ar',
      library: [
        entry('a', PlatformId.youtube, MediaKind.video, status: LibraryItem.statusFailed, error: Failure.network.name),
        entry('b', PlatformId.tiktok, MediaKind.video, status: LibraryItem.statusCancelled),
        entry('c', PlatformId.instagram, MediaKind.video),
      ],
    );
    await tester.tap(find.text('التحميلات').last);
    await tester.pumpAndSettle();
    expect(find.text('النت انقطع.'), findsOneWidget);
    expect(find.text('أُلغي'), findsOneWidget);
    expect(find.text('حاول مرة ثانية'), findsNWidgets(2));
    expect(find.text('الملف انحذف'), findsOneWidget);
    expect(find.text('نزّله مرة ثانية'), findsOneWidget);
  });

  testWidgets('library: delete asks first when a file would go with it', (tester) async {
    final controller = await boot(
      tester,
      library: [
        entry('keep', PlatformId.reddit, MediaKind.video, onDisk: true, title: 'Kept clip'),
        entry('gone', PlatformId.x, MediaKind.video, status: LibraryItem.statusFailed, title: 'Failed clip'),
      ],
    );
    final file = File(controller.library.first.paths.first);
    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    // The corner of a tile, clear of the buttons a stopped one shows.
    Future<void> open(int index) async {
      await tester.tapAt(tester.getTopLeft(find.byType(LibraryTile).at(index)) + const Offset(12, 12));
      await tester.pumpAndSettle();
    }

    await open(0);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this download?'), findsOneWidget);
    expect(find.text('Nazzil deletes its own copy. Downloads/Nazzil is left as it is.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.library.length, 2);
    expect(file.existsSync(), isTrue);

    await open(0);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(controller.library.map((e) => e.id), ['gone']);
    expect(file.existsSync(), isFalse);

    await open(0);
    expect(find.text('Try again'), findsWidgets);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this download?'), findsNothing);
    expect(controller.library, isEmpty);
    expect(find.text('Nothing saved yet'), findsOneWidget);
    expect(find.text('0 items'), findsNothing);
    expect(find.text('Photos'), findsNothing, reason: 'no filters over an empty library');
    await tester.tap(find.text('Add a link'));
    await tester.pumpAndSettle();
    expect(find.text('Download the video. Keep it.'), findsOneWidget);
  });

  testWidgets('library sheet: Open file says so when nothing opens it, and Linux gets no Share', (tester) async {
    await boot(tester, library: [entry('clip', PlatformId.reddit, MediaKind.video, onDisk: true)]);
    // As on a real Linux desktop: the launch call claims success either way,
    // and only the question beforehand tells whether an app exists.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async => call.method != 'canLaunch',
    );
    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getTopLeft(find.byType(LibraryTile)) + const Offset(12, 12));
    await tester.pumpAndSettle();
    // share_plus throws for files on Linux, where these tests run.
    expect(find.text('Share'), findsNothing);
    await tester.tap(find.text('Open file'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing on this computer could open it. It was saved to Downloads/Nazzil.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing on this computer'), findsNothing);
  });

  testWidgets('viewer: a missing file gets words and two ways out', (tester) async {
    final controller = await boot(tester);
    for (final kind in [MediaKind.video, MediaKind.photo]) {
      final item = entry('missing-${kind.name}', PlatformId.youtube, kind);
      await tester.pumpWidget(
        MaterialApp(
          theme: NazzilTheme.dark(NazzilPalette.rose, arabic: false),
          home: ViewerScreen(controller: controller, item: item),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text("Nazzil's copy of this file is gone."), findsOneWidget);
      expect(find.text('Download again'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
    }
  });

  testWidgets('viewer: a video nothing on the computer can open says so', (tester) async {
    final controller = await boot(tester);
    final asked = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        asked.add('${call.method} ${(call.arguments as Map)['url']}');
        return call.method != 'canLaunch';
      },
    );
    final item = entry('clip', PlatformId.reddit, MediaKind.video, onDisk: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: NazzilTheme.dark(NazzilPalette.rose, arabic: false),
        home: ViewerScreen(controller: controller, item: item),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing on this computer could open it'), findsNothing);
    await tester.tap(find.byTooltip('Play'));
    await tester.pumpAndSettle();
    expect(asked.single, allOf(startsWith('canLaunch '), endsWith('/clip.mp4')));
    expect(find.text('Nothing on this computer could open it. It was saved to Downloads/Nazzil.'), findsOneWidget);
  });

  testWidgets('converting: the label says so and Pause goes, since nothing is left to pause', (tester) async {
    final controller = await boot(tester, size: const Size(360, 1400));
    final job = entry(
      'job',
      PlatformId.youtube,
      MediaKind.video,
      status: LibraryItem.statusDownloading,
      videoKey: LinkParser.identityKey(sampleVideo.webpageUrl, sampleVideo.id),
    );
    controller
      ..library = [job]
      ..activeJobId = job.id
      ..downloading = true
      ..progress = 0.5
      ..media = sampleVideo
      ..selected = sampleVideo.options.first
      ..notifyListeners();
    await tester.pump();
    expect(find.text('Downloading… 50%'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);

    controller
      ..converting = true
      ..notifyListeners();
    await tester.pump();
    expect(find.text('Downloading… 50%'), findsNothing);
    // Once in the header, once on the button.
    expect(find.text('Converting…'), findsNWidgets(2));
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);

    controller.goTab(1);
    await tester.pump();
    final tile = find.byType(LibraryTile);
    expect(find.descendant(of: tile, matching: find.text('Converting…')), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('Pause')), findsNothing);
    expect(find.descendant(of: tile, matching: find.text('Cancel')), findsOneWidget);
  });

  testWidgets('viewer: an album turns by button and by arrow key, not only by swipe', (tester) async {
    final controller = await boot(tester);
    final paths = [
      for (var i = 0; i < 3; i++) (File('${scratch.path}/p$i.jpg')..writeAsBytesSync([0])).path,
    ];
    final album = entry('album', PlatformId.tiktok, MediaKind.photo, photoCount: 3).copyWith(paths: paths);
    await tester.pumpWidget(
      MaterialApp(
        theme: NazzilTheme.dark(NazzilPalette.rose, arabic: false),
        home: ViewerScreen(controller: controller, item: album),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 3'), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left_rounded)).onPressed, isNull);

    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 3'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('3 of 3'), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right_rounded)).onPressed, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3'), findsOneWidget);

    final single = entry('one', PlatformId.pinterest, MediaKind.photo).copyWith(paths: [paths.first]);
    await tester.pumpWidget(
      MaterialApp(
        theme: NazzilTheme.dark(NazzilPalette.rose, arabic: false),
        home: ViewerScreen(key: const ValueKey('one'), controller: controller, item: single),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Next'), findsNothing, reason: 'one photo needs no counter');
  });

  testWidgets('home: an album preview turns by button too', (tester) async {
    final controller = await boot(tester, size: const Size(360, 1200));
    const urls = ['https://example.com/1.jpg', 'https://example.com/2.jpg', 'https://example.com/3.jpg'];
    const album = MediaInfo(
      id: 'alb',
      title: 'Weekend in Erbil',
      webpageUrl: 'https://www.tiktok.com/@someone/photo/1',
      platform: PlatformId.tiktok,
      photos: urls,
      options: [QualityOption(id: 'photos', label: 'Photos', ext: 'jpg', kind: MediaKind.photo, photoUrls: urls)],
    );
    controller
      ..media = album
      ..selected = album.options.first
      ..notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('TikTok · 3 photos'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.photoIndex, 1);
    expect(find.text('2 of 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.photoIndex, 0);
    // Lets the image cache's clean-up timer run out before the test ends.
    await tester.pump(const Duration(seconds: 11));
  });

  test('a title reads in the direction of its first letter', () {
    expect(directionOf('Classic Cheesecake Recipe'), TextDirection.ltr);
    expect(directionOf('طريقة عمل الكيك'), TextDirection.rtl);
    expect(directionOf('2024 أفضل الأهداف'), TextDirection.rtl);
    expect(directionOf('❤️ CATS 💙'), TextDirection.ltr);
    expect(directionOf('😀 قطط'), TextDirection.rtl);
    expect(directionOf('12:30 !?'), isNull);
  });

  testWidgets('an English title in the Arabic app is cut at its own end', (tester) async {
    await boot(
      tester,
      language: 'ar',
      library: [
        entry('a', PlatformId.reddit, MediaKind.video, onDisk: true, title: 'A long English title that cannot fit on two lines of a tile'),
        entry('b', PlatformId.tiktok, MediaKind.video, onDisk: true, title: 'عنوان عربي طويل جدا ما يكفيه سطرين داخل المربع الصغير هذا'),
      ],
    );
    await tester.tap(find.text('التحميلات').last);
    await tester.pumpAndSettle();
    final english = tester.widget<Text>(find.textContaining('A long English title'));
    final arabic = tester.widget<Text>(find.textContaining('عنوان عربي'));
    expect(english.textDirection, TextDirection.ltr);
    expect(arabic.textDirection, TextDirection.rtl);
    expect(english.textAlign, TextAlign.right);
    expect(arabic.textAlign, TextAlign.right);
  });

  testWidgets('wide window: link box and library side by side, no tab bar', (tester) async {
    await boot(
      tester,
      size: const Size(1280, 800),
      library: [
        for (var i = 0; i < 6; i++) entry('w$i', PlatformId.values[i], MediaKind.video, onDisk: true),
      ],
    );
    expect(find.text('Download the video. Keep it.'), findsOneWidget);
    expect(find.text('6 items'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    final first = tester.getTopLeft(find.byType(LibraryTile).at(0));
    final fourth = tester.getTopLeft(find.byType(LibraryTile).at(3));
    expect(fourth.dy, first.dy, reason: 'at least four tiles share the first row');
  });

  testWidgets('done dialog: confetti runs once, and not at all under reduce motion', (tester) async {
    Widget dialog() => MaterialApp(
          theme: NazzilTheme.dark(NazzilPalette.rose, arabic: false),
          home: Scaffold(
            body: DoneSheet(s: const S('en'), photos: false, onView: () {}, onShare: () {}, onClose: () {}),
          ),
        );
    await tester.pumpWidget(dialog());
    expect(find.byType(ConfettiBurst), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(dialog());
    expect(find.byType(ConfettiBurst), findsNothing);
  });

  testWidgets('accessibility guidelines: tap targets, labels and text contrast', (tester) async {
    final handle = tester.ensureSemantics();
    for (final (theme, language, palette) in [
      ('dark', 'en', 'emerald'),
      ('light', 'en', 'sunset'),
      ('dark', 'ar', 'grape'),
      ('light', 'ar', 'rose'),
    ]) {
      // A screen tall enough to show each page whole: text cut by the edge
      // of a scroll area gets measured against whatever sits beside it.
      final controller = await boot(
        tester,
        theme: theme,
        language: language,
        palette: palette,
        size: const Size(360, 2400),
        library: [
          entry('a', PlatformId.reddit, MediaKind.video, onDisk: true),
          entry('b', PlatformId.x, MediaKind.video, status: LibraryItem.statusFailed, error: Failure.blocked.name),
          entry('c', PlatformId.tiktok, MediaKind.photo, photoCount: 4),
          entry('d', PlatformId.youtube, MediaKind.audio, status: LibraryItem.statusCancelled),
          entry('e', PlatformId.instagram, MediaKind.video),
        ],
      );
      Future<void> check(String where) async {
        final at = '$where, $theme $language';
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: at);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline), reason: at);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: at);
        // Flutter's own check reads the text colour off the pixels, which
        // fails on thin Arabic strokes at this scale; ours covers both.
        if (language == 'en') await expectLater(tester, meetsGuideline(textContrastGuideline), reason: at);
        final contrast = await measureContrast(tester);
        expect(contrast.faint, isEmpty, reason: at);
        expect(contrast.checked, greaterThan(3), reason: at);
        debugPrint('contrast $at: ${contrast.checked} texts and icons, lowest ${contrast.lowest.toStringAsFixed(2)}:1');
      }

      controller
        ..clipOffer = 'https://www.tiktok.com/@someone/video/1'
        ..failure = Failure.pasteFirst
        ..notifyListeners();
      await tester.pumpAndSettle();
      await check('home');
      controller
        ..clipOffer = null
        ..media = sampleVideo
        ..selected = sampleVideo.options.first
        ..failure = Failure.network
        ..notifyListeners();
      await tester.pumpAndSettle();
      await check('home result');
      controller.goTab(1);
      await tester.pumpAndSettle();
      await check('library');
      await tester.tapAt(tester.getTopLeft(find.byType(LibraryTile).first) + const Offset(12, 12));
      await tester.pumpAndSettle();
      await check('item sheet');
      await tester.tap(find.text(controller.s.delete));
      await tester.pumpAndSettle();
      await check('delete dialog');
      await tester.tap(find.text(controller.s.cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(controller.s.settings));
      await tester.pumpAndSettle();
      await check('settings');
      await tester.pumpWidget(const SizedBox());
    }
    handle.dispose();
  });

  testWidgets('the contrast measure itself catches faint text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: Color(0xFF202020),
          child: Center(
            child: Text('faint', style: TextStyle(color: Color(0xFF505050), fontSize: 15, decoration: TextDecoration.none)),
          ),
        ),
      ),
    );
    final contrast = await measureContrast(tester);
    expect(contrast.checked, 1);
    expect(contrast.faint.single, contains('2.02:1'));
  });

  testWidgets('keyboard: tab reaches the controls and shows a focus ring', (tester) async {
    final controller = await boot(tester, size: const Size(800, 900));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);

    int rings() => tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<ShapeDecoration>()
        .map((decoration) => decoration.shape)
        .whereType<OutlinedBorder>()
        .where((shape) => shape.side.width == 2 && shape.side.strokeAlign == BorderSide.strokeAlignOutside)
        .length;

    // One stop for the back button, then three languages, three themes and
    // five colours; the last stop is Grape.
    var ringed = 0;
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      if (rings() == 1) ringed++;
    }
    expect(ringed, 11);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.settings.palette, 'grape');
  });
}
