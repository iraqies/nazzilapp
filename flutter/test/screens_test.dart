import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/app.dart';
import 'package:nazzil/data/link_parser.dart';
import 'package:nazzil/data/settings_store.dart';
import 'package:nazzil/l10n/strings.dart';
import 'package:nazzil/models/media.dart';
import 'package:nazzil/state/nazzil_controller.dart';
import 'package:nazzil/theme/nazzil_theme.dart';
import 'package:nazzil/ui/screens/home_screen.dart';
import 'package:nazzil/ui/screens/viewer_screen.dart';
import 'package:nazzil/ui/widgets/arriving.dart';
import 'package:nazzil/ui/widgets/cover.dart';
import 'package:nazzil/ui/widgets/done_sheet.dart';
import 'package:nazzil/ui/widgets/library_tile.dart';
import 'package:nazzil/ui/widgets/link_frame.dart';
import 'package:nazzil/ui/widgets/logo.dart';
import 'package:nazzil/ui/widgets/nazzil_button.dart';
import 'package:nazzil/ui/widgets/tile.dart';
import 'package:nazzil/ui/widgets/title_text.dart';
import 'package:nazzil/ui/widgets/top_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pictures.dart';
import 'support/typefaces.dart';

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
  String? thumbnail,
  String quality = 'HD',
}) {
  final path = '${scratch.path}/$id.${kind == MediaKind.photo ? 'jpg' : 'mp4'}';
  if (onDisk) File(path).writeAsBytesSync([0]);
  return LibraryItem(
    id: id,
    title: title ?? 'Saved item $id',
    platform: platform,
    kind: kind,
    quality: quality,
    createdAt: DateTime(2026, 11, 10),
    sourceUrl: 'https://example.com/$id',
    videoKey: videoKey ?? '${platform.name}:$id',
    paths: status == LibraryItem.statusDone ? [path] : const [],
    photoCount: photoCount,
    thumbnail: thumbnail,
    status: status,
    error: error,
  );
}

Future<NazzilController> boot(
  WidgetTester tester, {
  String language = 'en',
  String theme = 'dark',
  List<LibraryItem> library = const [],
  Size size = const Size(360, 720),
  double textScale = 1,
  double statusBar = 0,
  double pixelRatio = 1,
  Map<String, Object> alsoStored = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'nazzil.language': language,
    'nazzil.theme.v2': theme,
    'nazzil.library.v2': jsonEncode([for (final item in library) item.toJson()]),
    ...alsoStored,
  });
  PackageInfo.setMockInitialValues(
    appName: 'Nazzil',
    packageName: 'com.nazzil.nazzil',
    version: '1.3.0',
    buildNumber: '22',
    buildSignature: '',
  );
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  tester.view.padding = FakeViewPadding(top: statusBar * pixelRatio);
  tester.view.viewPadding = FakeViewPadding(top: statusBar * pixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final controller = NazzilController();
  await tester.pumpWidget(NazzilApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

/// Writes a plain picture of the given size to the scratch folder, and returns where.
Future<String> picture(WidgetTester tester, String name, int width, int height, {Color color = const Color(0xFFCC3355)}) async {
  final path = '${scratch.path}/$name.png';
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = color);
    final image = await recorder.endRecording().toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
  return path;
}

/// Lets the pictures on the page arrive, or fail. Reading and decoding run in
/// real time, one stage per turn of the fake clock: a quick machine is done
/// in a few turns, a slow one gets ten seconds.
Future<void> pictures(WidgetTester tester) async {
  final cache = PaintingBinding.instance.imageCache;
  final clock = Stopwatch()..start();
  var turns = 0;
  do {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 120));
    turns++;
  } while ((turns < 3 || cache.pendingImageCount > 0) && clock.elapsed < const Duration(seconds: 10));
  await tester.pumpAndSettle();
}

/// The screen as pixels, for the checks that look at what was painted.
Future<({int width, int height, ByteData pixels})> capture(WidgetTester tester) async {
  final view = tester.binding.renderViews.first;
  // ignore: invalid_use_of_protected_member
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
  return (width: width, height: height, pixels: pixels);
}

/// The runs of letters in a paragraph, each with the style it ends up with.
List<({String words, TextStyle style})> runs(InlineSpan span, [TextStyle inherited = const TextStyle()]) {
  if (span is! TextSpan) return const [];
  final style = inherited.merge(span.style);
  final words = (span.text ?? '').trim();
  return [
    if (words.isNotEmpty) (words: words, style: style),
    for (final child in span.children ?? const <InlineSpan>[]) ...runs(child, style),
  ];
}

/// Measures every text and icon on the current page against the colour most
/// of the pixels around it have, and lists what misses WCAG AA.
///
/// The colour of the letters is the one their style names, checked against
/// what was painted: letters under an Opacity or a filter stop short of it,
/// and are then measured at the shade they did reach. Wants two pixels a
/// point or more, where a thin stroke still covers a whole pixel.
Future<({int checked, double lowest, List<String> faint})> measureContrast(WidgetTester tester) async {
  final shot = await capture(tester);
  final pixels = shot.pixels;
  final scale = tester.view.devicePixelRatio;
  int rgbAt(int x, int y) => pixels.getUint32((y * shot.width + x) * 4) >> 8;
  ({int left, int top, int right, int bottom}) onScreen(Rect box) => (
        left: (box.left * scale).floor().clamp(0, shot.width),
        top: (box.top * scale).floor().clamp(0, shot.height),
        right: (box.right * scale).ceil().clamp(0, shot.width),
        bottom: (box.bottom * scale).ceil().clamp(0, shot.height),
      );

  var checked = 0;
  var lowest = double.infinity;
  final faint = <String>[];
  // Each widget above a paragraph hands back the same one, so keep a set.
  for (final paragraph in tester.allRenderObjects.whereType<RenderParagraph>().toSet()) {
    if (!paragraph.hasSize) continue;
    // A page under a sheet or a dialog is dimmed and out of reach.
    final element = (paragraph.debugCreator! as DebugCreator).element;
    if (ModalRoute.of(element)?.isCurrent == false) continue;
    // Words kept in the tree to hold their place are not on screen.
    final hidden = element.findAncestorWidgetOfExactType<Visibility>();
    if (hidden != null && !hidden.visible) continue;
    final box = MatrixUtils.transformRect(paragraph.getTransformTo(null), Offset.zero & paragraph.size);
    final inside = onScreen(box);
    // Letters that fill their box to the edge still need a backdrop to stand on.
    final around = onScreen(box.inflate(2));
    if (inside.left >= inside.right || inside.top >= inside.bottom) continue;

    for (final run in runs(paragraph.text)) {
      final own = run.style.color;
      if (own == null) continue;
      final ownRgb = ((own.r * 255).round(), (own.g * 255).round(), (own.b * 255).round());

      final counts = <int, int>{};
      for (var y = around.top; y < around.bottom; y++) {
        for (var x = around.left; x < around.right; x++) {
          final rgb = rgbAt(x, y);
          final near = ((rgb >> 16) - ownRgb.$1).abs() <= 16 &&
              ((rgb >> 8 & 0xFF) - ownRgb.$2).abs() <= 16 &&
              ((rgb & 0xFF) - ownRgb.$3).abs() <= 16;
          if (!near) counts[rgb] = (counts[rgb] ?? 0) + 1;
        }
      }
      // Nothing but the colour of the letters: they stand on their own colour.
      final behind = counts.isEmpty
          ? own.withValues(alpha: 1)
          : Color(0xFF000000 | counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key);
      final named = Color.alphaBlend(own, behind);

      // How far along the way from the backdrop to their colour the letters get.
      final dr = (named.r - behind.r) * 255;
      final dg = (named.g - behind.g) * 255;
      final db = (named.b - behind.b) * 255;
      final way = dr * dr + dg * dg + db * db;
      var reach = way < 1 ? 1.0 : 0.0;
      for (var y = inside.top; y < inside.bottom && reach < 1; y++) {
        for (var x = inside.left; x < inside.right && reach < 1; x++) {
          final rgb = rgbAt(x, y);
          final pr = (rgb >> 16) - behind.r * 255;
          final pg = (rgb >> 8 & 0xFF) - behind.g * 255;
          final pb = (rgb & 0xFF) - behind.b * 255;
          final along = (pr * dr + pg * dg + pb * db) / way;
          if (along <= reach) continue;
          // Off that way altogether: something else in the box, not these letters.
          final or = pr - along * dr;
          final og = pg - along * dg;
          final ob = pb - along * db;
          if (or * or + og * og + ob * ob > 24 * 24) continue;
          reach = along.clamp(0.0, 1.0);
        }
      }
      final faded = reach < 0.75;
      final shown = faded ? Color.lerp(behind, named, reach)! : named;

      final a = shown.computeLuminance();
      final b = behind.computeLuminance();
      final contrast = (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
      final icon = run.style.fontFamily == 'MaterialIcons';
      final size = run.style.fontSize ?? 14;
      final large = size >= 24 || (size >= 18.66 && (run.style.fontWeight ?? FontWeight.w400).value >= 700);
      final needed = icon || large ? 3.0 : 4.5;
      checked++;
      if (contrast < lowest) lowest = contrast;
      if (contrast < needed) {
        faint.add(
          '${icon ? 'icon' : '"${run.words}"'} is ${contrast.toStringAsFixed(2)}:1, needs $needed '
          '(${faded ? 'painted at ${(reach * 100).round()}% of ' : ''}$own on $behind)',
        );
      }
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

/// The same post with a picture of its own, served from this machine.
MediaInfo pictured(String url, {String id = 'abc'}) => MediaInfo(
      id: id,
      title: sampleVideo.title,
      author: sampleVideo.author,
      webpageUrl: 'https://www.youtube.com/watch?v=$id',
      platform: sampleVideo.platform,
      duration: sampleVideo.duration,
      thumbnail: url,
      options: sampleVideo.options,
    );

LibraryItem jobFor(MediaInfo media, String status) => entry(
      'job',
      media.platform,
      MediaKind.video,
      status: status,
      videoKey: LinkParser.identityKey(media.webpageUrl, media.id),
      thumbnail: media.thumbnail,
    );

const linux = TargetPlatformVariant({TargetPlatform.linux});

void main() {
  setUp(() {
    scratch = Directory.systemTemp.createTempSync('nazzil-screens');
    // The stores ask the platform for a folder; tests have no platform.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => scratch.path,
    );
    // No network in tests: a picture comes from a file a test names, or fails at once.
    LocalPictures.serve();
    // Flutter keeps decoded pictures, and the ones still loading, from one test to the next.
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });
  tearDown(() => scratch.deleteSync(recursive: true));

  setUpAll(() async {
    // The icons ship with Flutter, beside the program that runs the tests.
    // Without them every icon is a plain square, which measures the same.
    final icons = File('${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts/MaterialIcons-Regular.otf');
    await loadShippedTypefaces();
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await loader.load();
    }
  });

  /// The logo in the header. It is drawn, so it is found by what it is and not by its letters;
  /// the empty Home shows the icon a second time, on the tile of the apps it works with.
  final logo = find.descendant(of: find.byType(TopBar), matching: find.byType(NazzilLogo));

  /// The tab at the bottom of a phone: after the page in the tree, so the last match.
  Finder tab(String label) => find.text(label).last;

  double scrolled(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first,
      )
      .position
      .pixels;

  testWidgets('home: Paste on an empty frame, Fetch once it holds words, and each mistake gets its own line', (tester) async {
    final controller = await boot(tester);
    var clipboard = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData' ? {'text': clipboard} : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    expect(logo, findsOneWidget);
    expect(tester.getSemantics(logo).label, 'Nazzil', reason: 'a screen reader says the name the logo writes');
    expect(find.text('Paste a link'), findsOneWidget);
    expect(find.text('or share a post to Nazzil from any app'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.text('Fetch'), findsNothing);
    expect(find.text('Recent'), findsNothing, reason: 'nothing is saved yet, so there is no strip');
    expect(find.byType(FilledButton), findsOneWidget, reason: 'one button for the next step');

    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    expect(find.text("No link on your clipboard. Copy a post's link first."), findsOneWidget);

    clipboard = 'look at https://example.com/nothing';
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    expect(find.text('This link is not from a supported app yet.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'https://example.com/nothing');
    expect(find.text('Paste'), findsNothing, reason: 'the frame holds a link now, so the button fetches');

    await controller.setLanguage('ar');
    await tester.pumpAndSettle();
    expect(find.text('هذا الرابط ليس من تطبيق مدعوم بعد.'), findsOneWidget);
    await controller.setLanguage('en');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not a link');
    await tester.pumpAndSettle();
    expect(find.text('This link is not from a supported app yet.'), findsNothing);
    await tester.tap(find.text('Fetch'));
    await tester.pumpAndSettle();
    expect(find.text('Paste a link first.'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(controller.url, isEmpty);
    expect(find.text('Paste a link first.'), findsNothing);
    expect(find.text('Paste'), findsOneWidget);
  });

  testWidgets('home: the link field leads the hero, with the paste button and then the hint under it', (tester) async {
    await boot(tester);
    final frame = tester.getRect(find.byType(LinkFrame));
    final button = tester.getRect(find.byType(FilledButton));
    // The field spans its tile within the tile's margins, as one compact row.
    expect(frame.width, 360 - 2 * 16 - 2 * 20);
    expect(frame.height, greaterThanOrEqualTo(52));
    expect(frame.height, lessThan(80), reason: 'a single row, not the old film-frame drop zone');
    // The link icon leads the field, and the prompt is its hint.
    expect(
      find.descendant(of: find.byType(LinkFrame), matching: find.byIcon(Icons.link_rounded)),
      findsOneWidget,
    );
    expect(find.text('Paste a link'), findsOneWidget);
    // Under the field comes the button that pastes, and under that the other way in.
    final hint = tester.getRect(find.text('or share a post to Nazzil from any app'));
    expect(button.top, greaterThan(frame.bottom));
    expect(hint.top, greaterThan(button.bottom));
    expect(find.widgetWithIcon(FilledButton, Icons.content_paste_rounded), findsOneWidget);

    // A tap on the field starts typing, and the field keeps its size.
    await tester.tap(find.byType(LinkFrame));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.bySemanticsLabel('Link'), findsOneWidget);
    expect(tester.getRect(find.byType(LinkFrame)), frame);
  });

  testWidgets('home result: one line of facts, no quality icons, and the colour on the one button that downloads', (tester) async {
    final controller = await boot(tester, theme: 'light');
    controller
      ..media = sampleVideo
      ..selected = sampleVideo.options.first
      ..notifyListeners();
    await tester.pumpAndSettle();
    // The facts are an eyebrow: set in capitals, and read out in the case they are written in.
    expect(find.text('YOUTUBE · 9:56'), findsOneWidget);
    expect(find.bySemanticsLabel('YouTube · 9:56'), findsOneWidget);
    expect(find.text('YouTube'), findsNothing);
    expect(find.byIcon(Icons.hd_outlined), findsNothing);
    expect(find.byType(LinkFrame), findsNothing, reason: 'the poster takes the place of the frame');
    expect(logo, findsNothing, reason: 'and of the header');

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    final style = (button.style ?? FilledButtonTheme.of(tester.element(find.byType(FilledButton))).style)!;
    expect(style.backgroundColor!.resolve({}), NazzilColors.tint);
    final label = tester.widget<Text>(find.text('Download'));
    expect(
      DefaultTextStyle.of(tester.element(find.text('Download'))).style.merge(label.style).color,
      NazzilColors.onTint,
    );

    // The picked quality rides a raised thumb; the rest of the segmented control is clear.
    Color? cell(String text) =>
        tester.widget<Material>(find.ancestor(of: find.text(text), matching: find.byType(Material)).first).color;
    expect(cell('HD'), isNot(Colors.transparent));
    expect(cell('SD'), Colors.transparent);
    await tester.tap(find.text('SD'));
    await tester.pumpAndSettle();
    expect(controller.selected?.id, 'sd');
    expect(cell('SD'), isNot(Colors.transparent));
    expect(cell('HD'), Colors.transparent);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(controller.media, isNull);
    expect(find.byType(LinkFrame), findsOneWidget);
  });

  testWidgets('poster: a hero fills the room, keeping the words and controls at the foot', (tester) async {
    final controller = await boot(tester);
    LocalPictures.serve({
      'https://pictures.example/flat.png': await picture(tester, 'flat', 400, 100),
      'https://pictures.example/tall.png': await picture(tester, 'tall', 100, 400),
    });
    final room = tester.getSize(find.byType(HomeScreen)).height;

    Future<double> show(MediaInfo media) async {
      controller
        ..media = media
        ..selected = media.options.first
        ..notifyListeners();
      await tester.pump();
      await pictures(tester);
      return tester.getSize(find.byType(NetPicture)).height;
    }

    // Whatever its shape, the video thumbnail is a hero that fills the room the
    // words and controls leave, cover-cropped, so a wide clip reads as large as a
    // tall one and the download sits low at the foot, not in the middle.
    final flat = await show(pictured('https://pictures.example/flat.png', id: 'f'));
    final tall = await show(pictured('https://pictures.example/tall.png', id: 't'));
    expect(flat, closeTo(tall, 0.01), reason: 'it fills, whatever the shape');
    expect(tall, greaterThan(360 * 9 / 16), reason: 'a hero, bigger than a film frame');
    // The controls take the foot: the last of them sits a little above the tabs,
    // far from the middle of the screen.
    final foot = inInclusiveRange(room - 40, room - 18);
    expect(
      tester.getRect(find.widgetWithText(FilledButton, 'Download')).bottom,
      foot,
      reason: 'the one download button hugs the foot, not the middle',
    );

    final post = pictured('https://pictures.example/tall.png', id: 't');
    // As the download runs, the picture stays a hero and the bar and the line that
    // stops it sit at the foot.
    controller
      ..library = [jobFor(post, LibraryItem.statusDownloading)]
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(NetPicture)).height, greaterThan(360 * 9 / 16));
    expect(
      tester.getRect(find.widgetWithText(TextButton, 'Cancel')).bottom,
      foot,
      reason: 'the controls hug the foot while it runs',
    );

    // A paused download is the tallest: Resume above the bar and the line that
    // cancels. The hero gives up the room, so they still sit at the foot.
    controller
      ..library = [jobFor(post, LibraryItem.statusPaused)]
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Resume'), findsOneWidget);
    expect(tester.getSize(find.byType(NetPicture)).height, greaterThan(360 * 9 / 16), reason: 'still a hero when paused');
    expect(
      tester.getRect(find.widgetWithText(TextButton, 'Cancel')).bottom,
      foot,
      reason: 'still at the foot when paused',
    );
    controller
      ..library = []
      ..notifyListeners();
    await tester.pumpAndSettle();

    // With no picture to go by, a plain block stands in, a hero too, button at the foot.
    controller
      ..media = sampleVideo
      ..selected = sampleVideo.options.first
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byType(NetPicture), findsNothing);
    final stand = find.ancestor(of: find.byIcon(Icons.videocam_outlined), matching: find.byType(ColoredBox)).first;
    expect(tester.getSize(stand).height, greaterThan(360 * 9 / 16), reason: 'the stand-in is a hero too');
    expect(tester.getRect(find.widgetWithText(FilledButton, 'Download')).bottom, foot);
  });

  testWidgets('poster: it runs under the status bar, and hands the bar back once scrolled away', (tester) async {
    final controller = await boot(tester, theme: 'light', statusBar: 30, size: const Size(360, 420), textScale: 2);
    LocalPictures.serve({'https://pictures.example/photo.png': await picture(tester, 'photo', 300, 200)});
    final media = pictured('https://pictures.example/photo.png');
    Brightness? clock() => SystemChrome.latestStyle?.statusBarIconBrightness;

    expect(tester.getRect(logo).top, greaterThanOrEqualTo(30), reason: 'the empty Home starts below the bar');
    expect(clock(), Brightness.dark);

    controller
      ..media = media
      ..selected = media.options.first
      ..notifyListeners();
    await tester.pump();
    await pictures(tester);
    expect(tester.getRect(find.byType(NetPicture)).top, 0);
    expect(tester.getRect(find.byTooltip('Clear')).top, greaterThanOrEqualTo(30), reason: 'the way out stays clear of the bar');
    expect(clock(), Brightness.light, reason: 'light figures over the picture and its fade');

    final poster = tester.getSize(find.byType(NetPicture)).height;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(scrolled(tester), greaterThan(poster - 30), reason: 'the poster has left but for the strip under the bar');
    expect(clock(), Brightness.dark, reason: 'the strip under the bar is the page again');
    // The words of the page pass under that strip, not behind the clock.
    final strip = tester.hitTestOnBinding(const Offset(180, 15)).path.map((entry) => entry.target.runtimeType.toString());
    expect(strip, isNot(contains('RenderParagraph')));
  });

  testWidgets('download: a bar fills under the post in colour, the number beside it, and the ways to stop below', (tester) async {
    final controller = await boot(tester);
    LocalPictures.serve({'https://pictures.example/photo.png': await picture(tester, 'photo', 300, 200)});
    final media = pictured('https://pictures.example/photo.png');
    final job = jobFor(media, LibraryItem.statusDownloading);
    double? bar() => tester.widget<DownloadBar>(find.byType(DownloadBar)).value;

    controller
      ..media = media
      ..selected = media.options.first
      ..notifyListeners();
    await tester.pump();
    await pictures(tester);
    expect(find.byType(DownloadBar), findsNothing, reason: 'a post that was only fetched shows no bar');
    expect(find.byType(ColorFiltered), findsNothing, reason: 'the post is shown in full colour');

    controller
      ..library = [job]
      ..activeJobId = job.id
      ..downloading = true
      ..progress = 0.5
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byType(DownloadBar), findsOneWidget);
    expect(bar(), closeTo(0.5, 0.001), reason: 'the bar stands for how much has arrived');
    expect(find.byType(ColorFiltered), findsNothing, reason: 'the post stays in colour while it downloads');
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Downloading…'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing, reason: 'nothing to start while it runs');

    controller
      ..converting = true
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(bar(), 1, reason: 'the whole file is here; only the conversion is left');
    expect(find.text('50%'), findsNothing);
    expect(find.text('Converting…'), findsOneWidget);
    expect(find.text('Pause'), findsNothing, reason: 'nothing is left to pause');
    expect(find.text('Cancel'), findsOneWidget);

    controller.goTab(1);
    await tester.pumpAndSettle();
    final tile = find.byType(LibraryTile);
    expect(find.descendant(of: tile, matching: find.text('Converting…')), findsOneWidget);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Pause'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Cancel'), findsOneWidget);
    await tester.tapAt(const Offset(180, 40));
    await tester.pumpAndSettle();

    controller
      ..converting = false
      ..downloading = false
      ..activeJobId = null
      ..library = [jobFor(media, LibraryItem.statusPaused)]
      ..goTab(0);
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Resume'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    expect(find.byType(DownloadBar), findsOneWidget, reason: 'a paused download still shows its bar');
  });

  testWidgets('download: in the Arabic app the bar fills from the right', (tester) async {
    final controller = await boot(tester, language: 'ar');
    LocalPictures.serve({'https://pictures.example/photo.png': await picture(tester, 'photo', 300, 200)});
    final media = pictured('https://pictures.example/photo.png');
    final job = jobFor(media, LibraryItem.statusDownloading);
    controller
      ..media = media
      ..selected = media.options.first
      ..library = [job]
      ..activeJobId = job.id
      ..downloading = true
      ..progress = 0.25
      ..notifyListeners();
    await tester.pump();
    await pictures(tester);
    final tint = NazzilColors.tint.toARGB32() & 0xFFFFFF;
    final bar = tester.getRect(find.byType(DownloadBar));
    final shot = await capture(tester);
    int at(double x) => shot.pixels.getUint32((bar.center.dy.round() * shot.width + x.round()) * 4);
    // A quarter in: the far (right) end carries the fill, the near (left) end is still the track.
    expect(at(bar.right - 8) >> 8, tint);
    expect(at(bar.left + 8) >> 8, isNot(tint));
  });

  testWidgets('a picture that is not on the device is grey, at 42% of its brightness', (tester) async {
    await tester.pumpWidget(
      const ColorFiltered(colorFilter: NazzilColors.unsaved, child: ColoredBox(color: Color(0xFFFFFFFF))),
    );
    final white = (await capture(tester)).pixels.getUint32(0);
    expect([white >> 24, white >> 16 & 0xFF, white >> 8 & 0xFF], everyElement(closeTo(0.42 * 255, 1)));
    await tester.pumpWidget(
      const ColorFiltered(colorFilter: NazzilColors.unsaved, child: ColoredBox(color: Color(0xFFFF0000))),
    );
    final red = (await capture(tester)).pixels.getUint32(0);
    expect(red >> 24, red >> 16 & 0xFF);
    expect(red >> 24, red >> 8 & 0xFF);
    expect(red >> 24, lessThan(white >> 24), reason: 'red is darker than white to the eye');
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
          statusBar: 24,
          library: [
            entry('a', PlatformId.reddit, MediaKind.video, onDisk: true, title: 'A long title that needs both of its lines to show'),
            entry('b', PlatformId.pinterest, MediaKind.photo, onDisk: true, photoCount: 12),
            entry('c', PlatformId.x, MediaKind.audio, status: LibraryItem.statusFailed, error: Failure.network.name),
            entry('d', PlatformId.tiktok, MediaKind.video),
          ],
        );
        // Short steps, so every part of the page gets painted on screen once.
        Future<void> sweep(Finder scrollable, String where) async {
          for (var step = 0; step < 16; step++) {
            await tester.drag(scrollable, const Offset(0, -240), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 50));
            expect(tester.takeException(), isNull, reason: '$where step $step');
          }
        }

        controller
          ..clipOffer = 'https://www.tiktok.com/@someone/video/1'
          ..failure = Failure.noLink
          ..notifyListeners();
        await tester.pump();
        await sweep(find.byType(CustomScrollView), 'home');

        controller
          ..loading = true
          ..setUrl('https://www.tiktok.com/@someone/video/7301112223334445556');
        await tester.pump();
        await sweep(find.byType(CustomScrollView), 'home while fetching');

        const urls = ['https://example.com/1.jpg', 'https://example.com/2.jpg'];
        const album = MediaInfo(
          id: 'alb',
          title: 'A weekend in Erbil with far more words than one line will ever hold',
          author: 'someone',
          webpageUrl: 'https://www.tiktok.com/@someone/photo/1',
          platform: PlatformId.tiktok,
          photos: urls,
          options: [
            QualityOption(id: 'photos', label: 'Photos', ext: 'jpg', kind: MediaKind.photo, photoUrls: urls),
            QualityOption(id: 'audio', label: 'Audio', ext: 'mp3', kind: MediaKind.audio, directUrl: 'https://example.com/a'),
          ],
        );
        controller
          ..loading = false
          ..clipOffer = null
          ..media = album
          ..selected = album.options.first
          ..failure = Failure.blocked
          ..notifyListeners();
        await tester.pump();
        await sweep(find.byType(CustomScrollView), 'album');

        final job = jobFor(sampleVideo, LibraryItem.statusDownloading);
        controller
          ..media = sampleVideo
          ..selected = sampleVideo.options.first
          ..library = [job, ...controller.library]
          ..activeJobId = job.id
          ..downloading = true
          ..progress = 0.5
          ..notifyListeners();
        await tester.pump();
        await sweep(find.byType(CustomScrollView), 'downloading');

        controller.goTab(1);
        await tester.pump();
        await sweep(find.byType(CustomScrollView), 'library');

        await tester.drag(find.byType(CustomScrollView), const Offset(0, 5000));
        await tester.pumpAndSettle();
        // At this size the heading and filters can fill the screen, so the tile is scrolled up to.
        await tester.ensureVisible(find.byType(LibraryTile).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(LibraryTile).at(1));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'item sheet');
        await sweep(find.descendant(of: find.byType(BottomSheet), matching: find.byType(SingleChildScrollView)), 'item sheet');
        await tester.tap(find.text(controller.s.delete));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'delete dialog');
        await tester.tap(find.text(controller.s.cancel));
        await tester.pumpAndSettle();
        // Back up to the header, which left the screen when the tile was scrolled to.
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 5000));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip(controller.s.settings));
        await tester.pump();
        await sweep(find.byType(ListView), 'settings');
      });
    }
  }

  for (final language in ['en', 'ar']) {
    for (final theme in ['dark', 'light']) {
      testWidgets('home: every app it works with wears the same badge, and the row fits a 320 wide phone at double text ($language, $theme)',
          (tester) async {
        await boot(tester, language: language, theme: theme, size: const Size(320, 640), textScale: 2);
        final badges = find.byType(PillBadge);
        await tester.scrollUntilVisible(
          badges.last,
          120,
          scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(badges, findsNWidgets(PlatformId.values.length - 1));

        final looks = {
          for (var i = 0; i < PlatformId.values.length - 1; i++)
            (
              tester.widget<DecoratedBox>(find.descendant(of: badges.at(i), matching: find.byType(DecoratedBox)).first).decoration,
              tester.widget<Text>(find.descendant(of: badges.at(i), matching: find.byType(Text))).style?.color,
            ),
        };
        expect(looks, hasLength(1), reason: 'no app is set apart from the others, as YouTube once was in gold');
      });
    }
  }

  testWidgets('settings: language and theme switch, and the choice is kept', (tester) async {
    await boot(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(Theme.of(tester.element(find.text('Dark'))).brightness, Brightness.dark, reason: 'dark is how Nazzil opens');

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Light'))).brightness, Brightness.light);
    expect((await SharedPreferences.getInstance()).getString('nazzil.theme.v2'), 'light');
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Dark'))).brightness, Brightness.dark);

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(Directionality.of(tester.element(find.text('العربية'))), TextDirection.rtl);
    expect(find.byTooltip('رجوع'), findsOneWidget);
    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();
    expect(find.text('الصق رابطًا'), findsOneWidget);
    expect(tester.getSemantics(logo).label, 'نزّل');
  });

  testWidgets("the phone's Back closes Settings, and on the first page puts the app behind without ending it",
      (tester) async {
    var ended = 0;
    // Android 13 and later hand Back to the app only while the app says it has a use for it.
    final asked = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') ended++;
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') asked.add(call.arguments as bool);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final toPhone = <String>[];
    const host = MethodChannel('nazzil/host');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(host, (call) async {
      toPhone.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(host, null));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await boot(tester);
    expect(asked, isNotEmpty);
    expect(asked, everyElement(isTrue), reason: 'the app asks the phone for Back from its first page on');

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsNothing);
    expect(find.text('Paste a link'), findsOneWidget);
    expect(toPhone, isEmpty, reason: 'Back in Settings goes back to the page, and the app stays in front');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(toPhone, ['toBack'], reason: 'on the first page Back puts the app behind');
    expect(find.text('Paste a link'), findsOneWidget);
    expect(ended, 0, reason: 'Back never ends the app: a running download would end with it');
    expect(asked, everyElement(isTrue));
  });

  testWidgets("a desktop has no Back of the phone's kind, and is asked nothing", variant: linux, (tester) async {
    final toPhone = <String>[];
    const host = MethodChannel('nazzil/host');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(host, (call) async {
      toPhone.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(host, null));
    await boot(tester, size: const Size(1320, 920));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(toPhone, isEmpty);
    expect(find.text('Paste a link, or press Ctrl+V'), findsOneWidget);
  });

  for (final earlier in ['sunset', 'rose']) {
    testWidgets('settings: there is no colour to pick, and a phone that had $earlier picked is in the tint', (tester) async {
      await boot(tester, alsoStored: {'nazzil.palette': earlier});
      final paste = find.byType(FilledButton);
      final style = (tester.widget<FilledButton>(paste).style ?? FilledButtonTheme.of(tester.element(paste)).style)!;
      expect(style.backgroundColor!.resolve({}), NazzilColors.tint);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Theme'), findsOneWidget);
      for (final word in ['Colour', 'Grape', 'Ocean', 'Emerald', 'Sunset', 'Rose']) {
        expect(find.text(word), findsNothing);
      }
      expect(find.byIcon(Icons.check_rounded), findsNothing, reason: 'the tick marked the picked colour');
    });
  }

  test('the controller says when the saved settings are read, so the app can wait to draw', () async {
    SharedPreferences.setMockInitialValues({
      'nazzil.language': 'ar',
      'nazzil.theme.v2': 'light',
    });
    PackageInfo.setMockInitialValues(
      appName: 'Nazzil',
      packageName: 'com.nazzil.nazzil',
      version: '1.3.0',
      buildNumber: '22',
      buildSignature: '',
    );
    final controller = NazzilController();
    expect(controller.settings.language, 'system', reason: 'nothing is read yet, these are the defaults');
    expect(controller.themeMode, ThemeMode.dark);
    await controller.settingsRead;
    expect(controller.s.isAr, isTrue);
    expect(controller.themeMode, ThemeMode.light);
  });

  test('settings store: dark is the default, and a choice of light made before is kept', () async {
    Future<String> themeFrom(Map<String, Object> stored) async {
      SharedPreferences.setMockInitialValues(stored);
      return (await SettingsStore().load()).theme;
    }

    expect(await themeFrom({}), 'dark');
    expect(await themeFrom({'nazzil.theme': 'light'}), 'light');
    expect(await themeFrom({'nazzil.theme': 'dark'}), 'dark');
    // "system" was the default before as often as it was a choice, so it moves to the new default.
    expect(await themeFrom({'nazzil.theme': 'system'}), 'dark');
    expect(await themeFrom({'nazzil.theme': 'light', 'nazzil.theme.v2': 'system'}), 'system');
  });

  testWidgets('library: counts, a tag on every picture, a filter for every app present, and both empty states', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = await boot(
      tester,
      library: [
        entry('a', PlatformId.reddit, MediaKind.video, onDisk: true),
        entry('b', PlatformId.pinterest, MediaKind.photo, onDisk: true, photoCount: 3),
        entry('c', PlatformId.x, MediaKind.video, onDisk: true),
      ],
    );
    await tester.tap(tab('Library'));
    await tester.pumpAndSettle();
    expect(find.text('3 ITEMS'), findsOneWidget);
    expect(find.text('3 photos'), findsOneWidget);
    expect(find.text('Video'), findsNWidgets(2));
    // The title is not on the picture; it is read out with the tag, and shown a tap away.
    expect(find.text('Saved item b'), findsNothing);
    expect(tester.getSemantics(find.byType(LibraryTile).at(1)).label, 'Saved item b, 3 photos');

    await tester.tap(find.text('All apps'));
    await tester.pumpAndSettle();
    for (final name in ['Reddit', 'Pinterest', 'X']) {
      expect(find.text(name), findsOneWidget, reason: '$name has something saved');
    }
    expect(find.text('YouTube'), findsNothing);
    expect(find.text('All apps'), findsNWidgets(2), reason: 'the button, and the row that is picked');
    await tester.tap(find.text('Reddit'));
    await tester.pumpAndSettle();
    expect(find.text('1 ITEM'), findsOneWidget);
    expect(find.text('Reddit'), findsOneWidget, reason: 'the button names the pick');
    expect(find.text('All apps'), findsNothing);

    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here for this filter'), findsOneWidget);
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.text('3 ITEMS'), findsOneWidget);
    expect(controller.libraryKind, 'all');
    expect(controller.libraryPlatform, 'all');
    handle.dispose();
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
    await tester.tap(tab('التنزيلات'));
    await tester.pumpAndSettle();
    expect(find.text('انقطع الاتصال.'), findsOneWidget);
    expect(find.text('أُلغي'), findsOneWidget);
    expect(find.text('حُذف الملف'), findsOneWidget);

    Future<void> open(int index) async {
      await tester.tap(find.byType(LibraryTile).at(index));
      await tester.pumpAndSettle();
    }

    Future<void> close() async {
      await tester.tapAt(const Offset(180, 40));
      await tester.pumpAndSettle();
    }

    await open(0);
    expect(find.text('انقطع الاتصال.'), findsNWidgets(2), reason: 'on the picture and in its sheet');
    expect(find.widgetWithText(ListTile, 'أعد المحاولة'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'شغّل'), findsNothing, reason: 'nothing to play yet');
    await close();

    await open(1);
    expect(find.text('أُلغي'), findsNWidgets(2));
    expect(find.widgetWithText(ListTile, 'أعد المحاولة'), findsOneWidget);
    await close();

    await open(2);
    expect(find.text('حُذف الملف'), findsNWidgets(2));
    expect(find.widgetWithText(ListTile, 'نزّله مرة أخرى'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'الأصل'), findsOneWidget);
  });

  testWidgets('library: a file with nothing in it is taken for gone', (tester) async {
    final cut = entry('cut', PlatformId.tiktok, MediaKind.video, onDisk: true, title: 'Cut short');
    File(cut.paths.single).writeAsBytesSync(const []);
    final controller = await boot(tester, library: [cut]);
    await tester.tap(tab('Library'));
    await tester.pumpAndSettle();
    expect(find.text('File was removed'), findsOneWidget);
    await tester.tap(find.byType(LibraryTile));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Play'), findsNothing, reason: 'there is nothing to play');
    expect(find.widgetWithText(ListTile, 'Download again'), findsOneWidget);
    // Nothing would be lost with it, so Delete does not ask.
    await tester.tap(find.text('Delete'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Delete this download?'), findsNothing);
    expect(controller.library, isEmpty);
    expect(File(cut.paths.single).existsSync(), isFalse);
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
    await tester.tap(tab('Library'));
    await tester.pumpAndSettle();
    Future<void> open(int index) async {
      await tester.tap(find.byType(LibraryTile).at(index));
      await tester.pumpAndSettle();
    }

    await open(0);
    expect(find.text('Kept clip'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this download?'), findsOneWidget);
    expect(find.text('Nazzil deletes its own copy. Your gallery and files are left as they are.'), findsOneWidget);
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
    expect(find.widgetWithText(ListTile, 'Try again'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this download?'), findsNothing);
    expect(controller.library, isEmpty);
    expect(find.text('Nothing saved yet'), findsOneWidget);
    expect(find.text('0 ITEMS'), findsNothing);
    expect(find.text('Photos'), findsNothing, reason: 'no filters over an empty library');
    await tester.tap(find.text('Add a link'));
    await tester.pumpAndSettle();
    expect(find.byType(LinkFrame), findsOneWidget);
  });

  testWidgets('library tile: a saved photo is its own cover, a video keeps the site picture', (tester) async {
    Widget tile(LibraryItem item) => MaterialApp(
          theme: NazzilTheme.dark(arabic: false),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 160,
                height: 160 / LibraryTile.ratio,
                child: LibraryTile(item: item, s: const S('en'), kept: true, onOpen: () {}),
              ),
            ),
          ),
        );
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const small = 'https://example.com/small.jpg';

    final photo = entry('pic', PlatformId.reddit, MediaKind.photo, onDisk: true).copyWith(thumbnail: small);
    await tester.pumpWidget(tile(photo));
    final cover = tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    expect((cover.imageProvider as FileImage).file.path, photo.paths.first);
    // 160 wide makes the frame 213 high; at 2 pixels a point, with half again in hand, that is 640.
    expect((cover.width, cover.height, cover.policy), (640, 640, ResizeImagePolicy.fit));
    expect(find.byType(CachedNetworkImage), findsNothing);

    final clip = entry('clip', PlatformId.reddit, MediaKind.video, onDisk: true).copyWith(thumbnail: small);
    await tester.pumpWidget(tile(clip));
    expect(tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).imageUrl, small);
    await tester.pumpAndSettle();
  });

  for (final language in ['en', 'ar']) {
    testWidgets("library tile: on the narrow frames of Home's strip no word of a tag is cut in two ($language)", (tester) async {
      // What a download can end on, with the failure lines whose words are the longest.
      final ends = [
        entry('stopped', PlatformId.tiktok, MediaKind.video, status: LibraryItem.statusCancelled),
        entry('held', PlatformId.tiktok, MediaKind.video, status: LibraryItem.statusPaused),
        entry('dropped', PlatformId.tiktok, MediaKind.video, status: LibraryItem.statusFailed, error: Failure.network.name),
        entry('refused', PlatformId.tiktok, MediaKind.video, status: LibraryItem.statusFailed, error: Failure.permission.name),
        entry('unmade', PlatformId.tiktok, MediaKind.video, status: LibraryItem.statusFailed, error: Failure.convert.name),
        entry('removed', PlatformId.tiktok, MediaKind.video),
      ];
      // Wide enough for the six to be on screen at once, and still a phone's one column.
      await boot(tester, language: language, size: const Size(800, 720), library: ends);
      final tiles = find.byType(LibraryTile);
      expect(tiles, findsNWidgets(ends.length));
      final said = <String>[];
      for (var i = 0; i < ends.length; i++) {
        final words = find.descendant(of: tiles.at(i), matching: find.byType(Text));
        final text = tester.widget<Text>(words).data!;
        said.add(text);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: words, matching: find.byType(RichText)),
        );
        for (final word in RegExp(r'\S+').allMatches(text)) {
          // Each box as high as its line: a full stop set in the other typeface is not a line of its own.
          final lines = paragraph
              .getBoxesForSelection(
                TextSelection(baseOffset: word.start, extentOffset: word.end),
                boxHeightStyle: ui.BoxHeightStyle.max,
              )
              .map((box) => box.top)
              .toSet();
          expect(lines.length, lessThan(2), reason: '"${word[0]}" of "$text" is cut in two');
        }
      }
      if (language == 'en') {
        expect(said.take(2), ['Cancelled', 'Paused']);
        expect(said.last, 'File was removed');
      }
    });
  }

  testWidgets('library sheet on a phone: gallery and share, and a line when no app opens the file', (tester) async {
    await boot(tester, library: [entry('clip', PlatformId.reddit, MediaKind.video, onDisk: true, title: 'A clip')]);
    // Only the question beforehand tells whether an app exists for the file.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async => call.method != 'canLaunch',
    );
    await tester.tap(tab('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LibraryTile));
    await tester.pumpAndSettle();
    expect(find.text('A clip'), findsOneWidget);
    expect(find.text('Reddit · Video · HD'), findsOneWidget, reason: 'two saves of one video differ only in the quality');
    expect(
      [for (final row in tester.widgetList<ListTile>(find.byType(ListTile))) (row.title! as Text).data],
      ['Play', 'Open in gallery', 'Share', 'Original', 'Delete'],
    );
    expect(
      find.descendant(of: find.widgetWithText(ListTile, 'Open in gallery'), matching: find.byIcon(Icons.photo_library_outlined)),
      findsOneWidget,
    );
    await tester.tap(find.text('Open in gallery'));
    await tester.pumpAndSettle();
    expect(find.text('No app on this phone could open it.'), findsOneWidget);
    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThanOrEqualTo(tester.getRect(tab('Library')).top),
      reason: 'the message floats above the tabs and leaves them in reach',
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.textContaining('No app on this phone'), findsNothing);
  });

  testWidgets('library sheet: its rows go on working when the page under it has changed', (tester) async {
    final controller = await boot(
      tester,
      library: [entry('clip', PlatformId.reddit, MediaKind.video, onDisk: true, title: 'A clip')],
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async => call.method != 'canLaunch',
    );
    // A share from another app takes the app to Home, and a tap on a notification to the
    // Library, whatever sheet is open at the time.
    Future<void> openThenLeave() async {
      controller.goTab(1);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(LibraryTile).first);
      await tester.pumpAndSettle();
      controller.goTab(0);
      await tester.pumpAndSettle();
      expect(find.byType(LinkFrame), findsOneWidget, reason: 'Home is under the sheet now');
      expect(find.widgetWithText(ListTile, 'Delete'), findsOneWidget, reason: 'and the sheet is still up');
    }

    await openThenLeave();
    await tester.tap(find.text('Open in gallery'));
    await tester.pumpAndSettle();
    expect(find.text('No app on this phone could open it.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await openThenLeave();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this download?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.library, hasLength(1));

    await openThenLeave();
    await tester.tap(find.text('Play'));
    // No video player exists in a test, so the viewer never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ViewerScreen), findsOneWidget);
  });

  testWidgets('library sheet: a video says which quality it was saved in, in the words of the quality buttons', (tester) async {
    final controller = await boot(
      tester,
      size: const Size(360, 1200),
      library: [
        entry('hd', PlatformId.reddit, MediaKind.video, onDisk: true),
        entry('sd', PlatformId.reddit, MediaKind.video, onDisk: true, quality: 'SD'),
        entry('gif', PlatformId.reddit, MediaKind.video, onDisk: true, quality: 'GIF'),
        entry('show', PlatformId.reddit, MediaKind.video, onDisk: true, quality: 'Video'),
        entry('sound', PlatformId.reddit, MediaKind.audio, onDisk: true, quality: 'Audio'),
      ],
    );
    await tester.tap(tab('Library'));
    await tester.pumpAndSettle();
    Future<void> facts(int tile, String line) async {
      await tester.tap(find.byType(LibraryTile).at(tile));
      await tester.pumpAndSettle();
      expect(find.text(line), findsOneWidget);
      await tester.tapAt(const Offset(180, 40));
      await tester.pumpAndSettle();
    }

    await facts(0, 'Reddit · Video · HD');
    await facts(1, 'Reddit · Video · SD');
    await facts(2, 'Reddit · Video · GIF');
    await facts(3, 'Reddit · Video');
    await facts(4, 'Reddit · Audio');

    await controller.setLanguage('ar');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LibraryTile).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('جودة عالية'), findsOneWidget);
  });

  testWidgets(
    'library sheet on Linux: Open file says so when nothing opens it, and there is no Share',
    (tester) async {
      await boot(tester, library: [entry('clip', PlatformId.reddit, MediaKind.video, onDisk: true)]);
      // As on a real Linux desktop: the launch call claims success either way,
      // and only the question beforehand tells whether an app exists.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async => call.method != 'canLaunch',
      );
      await tester.tap(tab('Library'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(LibraryTile));
      await tester.pumpAndSettle();
      // share_plus throws for files on Linux.
      expect(find.text('Share'), findsNothing);
      // On a computer the row shows "opens elsewhere", not a stack of photos.
      expect(
        find.descendant(of: find.widgetWithText(ListTile, 'Open file'), matching: find.byIcon(Icons.open_in_new_rounded)),
        findsOneWidget,
      );
      await tester.tap(find.text('Open file'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing on this computer could open it. It was saved to Downloads/Nazzil.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
    variant: linux,
  );

  testWidgets('home: the last saves run along the bottom, open their sheet, and lead to the library', (tester) async {
    final controller = await boot(
      tester,
      library: [
        for (var i = 0; i < 14; i++)
          entry('r$i', PlatformId.reddit, MediaKind.video, onDisk: true, title: 'Clip number $i'),
      ],
    );
    expect(find.text('Recent'), findsOneWidget);
    final strip = find.byType(LibraryTile);
    expect(tester.getRect(strip.first).left, 20, reason: 'the strip starts on the margin of the page');
    final page = tester.getRect(find.byType(HomeScreen));
    expect(tester.getRect(strip.first).bottom, page.bottom - 24, reason: 'and sits at the bottom of the screen');
    expect(tester.getRect(find.byType(FilledButton)).bottom, lessThan(tester.getRect(find.text('Recent')).top));

    // Twelve at most, however many are saved.
    await tester.drag(strip.first, const Offset(-3000, 0));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(strip.last).label, startsWith('Clip number 11'));

    await tester.tap(strip.last);
    await tester.pumpAndSettle();
    expect(find.text('Clip number 11'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Play'), findsOneWidget);
    await tester.tapAt(const Offset(180, 40));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Library'));
    await tester.pumpAndSettle();
    expect(controller.tab, 1);
    expect(find.text('14 ITEMS'), findsOneWidget);
  });

  testWidgets('home: a link on the clipboard is offered in a bar that can be taken or closed', (tester) async {
    final controller = await boot(tester);
    controller
      ..clipOffer = 'https://www.tiktok.com/@someone/video/1'
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('A supported link is on your clipboard'), findsOneWidget);
    final offer = tester.getRect(find.widgetWithText(OutlinedButton, 'Fetch this'));
    expect(offer.bottom, lessThanOrEqualTo(tester.getRect(tab('Home')).top), reason: 'above the tabs');
    expect(offer.top, greaterThan(tester.getRect(find.byType(FilledButton)).bottom), reason: 'and clear of the button');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(controller.clipOffer, isNull);
    expect(find.text('A supported link is on your clipboard'), findsNothing);
  });

  testWidgets('header: it says what is downloading, and nothing when nothing is', (tester) async {
    final controller = await boot(tester);
    final header = find.ancestor(of: logo, matching: find.byType(Column)).first;
    Iterable<String?> lines() => tester.widgetList<Text>(find.descendant(of: header, matching: find.byType(Text))).map((t) => t.data);
    expect(lines(), isEmpty);

    controller
      ..library = [
        entry('j1', PlatformId.youtube, MediaKind.video, status: LibraryItem.statusDownloading),
        entry('j2', PlatformId.youtube, MediaKind.video, status: LibraryItem.statusQueued),
      ]
      ..activeJobId = 'j1'
      ..downloading = true
      ..progress = 0.3
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(lines(), ['Downloading… · 1 waiting']);
    expect(find.descendant(of: find.byType(LibraryTile).first, matching: find.text('30%')), findsOneWidget);

    controller
      ..converting = true
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(lines(), ['Converting… · 1 waiting']);

    controller
      ..converting = false
      ..downloading = false
      ..activeJobId = null
      ..library = [entry('j1', PlatformId.youtube, MediaKind.video, status: LibraryItem.statusPaused)]
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(lines(), ['Paused']);

    // Reading a link is said on the button, once.
    controller
      ..library = []
      ..loading = true
      ..setUrl('https://www.tiktok.com/@someone/video/1');
    await tester.pump();
    expect(lines(), isEmpty);
    expect(find.text('Reading the link…'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    controller
      ..loading = false
      ..notifyListeners();
    await tester.pumpAndSettle();
  });

  testWidgets('viewer: a missing file gets words and two ways out, in a dark room whatever the theme', (tester) async {
    final controller = await boot(tester);
    for (final kind in [MediaKind.video, MediaKind.photo]) {
      final item = entry('missing-${kind.name}', PlatformId.youtube, kind);
      await tester.pumpWidget(
        MaterialApp(
          theme: NazzilTheme.light(arabic: false),
          home: ViewerScreen(controller: controller, item: item),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text("Nazzil's copy of this file is gone."), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Download again'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Original'), findsOneWidget);
      final theme = Theme.of(tester.element(find.text('Download again')));
      expect(theme.brightness, Brightness.dark);
      expect(tester.widget<Material>(find.byType(Material).first).color, theme.colorScheme.surface);
      expect(SystemChrome.latestStyle?.systemNavigationBarColor, theme.colorScheme.surface);
    }
  });

  testWidgets('viewer on a phone: a video that will not play says so and offers the gallery', (tester) async {
    final controller = await boot(tester);
    final item = entry('clip', PlatformId.reddit, MediaKind.video, onDisk: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: NazzilTheme.dark(arabic: false),
        home: ViewerScreen(controller: controller, item: item),
      ),
    );
    // No video player exists in a test, which is the failure this screen has words for.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('This video will not play here.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Open in gallery'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Original'), findsOneWidget);
  });

  testWidgets(
    'viewer on Linux: a video nothing on the computer can open says so',
    (tester) async {
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
          theme: NazzilTheme.dark(arabic: false),
          home: ViewerScreen(controller: controller, item: item),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Nothing on this computer could open it'), findsNothing);
      await tester.tap(find.byTooltip('Play'));
      await tester.pumpAndSettle();
      expect(asked.single, allOf(startsWith('canLaunch '), endsWith('/clip.mp4')));
      expect(find.text('Nothing on this computer could open it. It was saved to Downloads/Nazzil.'), findsOneWidget);
    },
    variant: linux,
  );

  testWidgets('viewer: an album turns by button and by arrow key, not only by swipe', (tester) async {
    final controller = await boot(tester);
    final paths = [
      for (var i = 0; i < 3; i++) (File('${scratch.path}/p$i.jpg')..writeAsBytesSync([0])).path,
    ];
    final album = entry('album', PlatformId.tiktok, MediaKind.photo, photoCount: 3).copyWith(paths: paths);
    await tester.pumpWidget(
      MaterialApp(
        theme: NazzilTheme.dark(arabic: false),
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

    // Every stop of the Tab key is a control: the screen itself, which listens for the arrows, is not one.
    final screen = tester.getSize(find.byType(ViewerScreen));
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus!.size.height, lessThan(screen.height / 2), reason: 'stop $i');
    }

    final single = entry('one', PlatformId.pinterest, MediaKind.photo).copyWith(paths: [paths.first]);
    await tester.pumpWidget(
      MaterialApp(
        theme: NazzilTheme.dark(arabic: false),
        home: ViewerScreen(key: const ValueKey('one'), controller: controller, item: single),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Next'), findsNothing, reason: 'one photo needs no counter');
  });

  testWidgets('home: the choices of a GIF post are worded in the app\'s language', (tester) async {
    final controller = await boot(tester, language: 'ar');
    const post = MediaInfo(
      id: 'gif',
      title: 'Toyota AE86',
      webpageUrl: 'https://www.reddit.com/comments/1xr9o61',
      platform: PlatformId.reddit,
      photos: ['https://example.com/1.gif'],
      options: [
        QualityOption(id: 'rd-gif', label: 'GIF', ext: 'mp4', kind: MediaKind.video, directUrl: 'https://example.com/1.mp4'),
        QualityOption(id: 'rd-gif-file', label: 'GIF file', ext: 'gif', kind: MediaKind.photo, photoUrls: ['https://example.com/1.gif']),
      ],
    );
    controller
      ..media = post
      ..selected = post.options.first
      ..notifyListeners();
    await tester.pump();
    await pictures(tester);
    // GIF is the name of a format and stays as it is written everywhere.
    expect(find.text('GIF'), findsOneWidget);
    expect(find.text('ملف GIF'), findsOneWidget);
    expect(find.text('GIF file'), findsNothing);
  });

  testWidgets('home: an album preview turns by button too, and a photo that fails to load says so', (tester) async {
    final controller = await boot(tester);
    LocalPictures.serve({'https://pictures.example/1.png': await picture(tester, 'one', 300, 200)});
    const urls = ['https://pictures.example/1.png', 'https://example.com/2.jpg', 'https://example.com/3.jpg'];
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
    await pictures(tester);
    expect(find.text('TIKTOK · 3 PHOTOS'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save photos'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Save this photo'), findsOneWidget);
    expect(find.text('Could not load this photo.'), findsNothing);
    // The frame takes the shape of the first photo.
    expect(tester.getSize(find.byType(PageView)).height, closeTo(240, 0.01));

    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(controller.photoIndex, 1);
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.text('Could not load this photo.'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous'));
    await tester.pumpAndSettle();
    expect(controller.photoIndex, 0);
  });

  testWidgets('home: an album fetched again shows its first photo, not the one it was left on', (tester) async {
    final controller = await boot(tester);
    const urls = ['https://example.com/1.jpg', 'https://example.com/2.jpg', 'https://example.com/3.jpg'];
    const album = MediaInfo(
      id: 'alb',
      title: 'Weekend in Erbil',
      webpageUrl: 'https://www.tiktok.com/@someone/photo/1',
      platform: PlatformId.tiktok,
      photos: urls,
      options: [QualityOption(id: 'photos', label: 'Photos', ext: 'jpg', kind: MediaKind.photo, photoUrls: urls)],
    );
    Future<void> fetched() async {
      controller
        ..media = album
        ..selected = album.options.first
        ..photoIndex = 0
        ..notifyListeners();
      await tester.pumpAndSettle();
    }

    double page() => tester.widget<PageView>(find.byType(PageView)).controller!.page!;

    await fetched();
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 3'), findsOneWidget);
    expect(page(), 2);

    controller
      ..media = null
      ..selected = null
      ..notifyListeners();
    await tester.pumpAndSettle();
    await fetched();
    expect(find.text('1 of 3'), findsOneWidget);
    expect(page(), 0, reason: 'the photo on show is the one the count and Save this photo mean');
  });

  testWidgets('home: the page, the link in the frame and the strip of last saves each keep their own place', (tester) async {
    final controller = await boot(
      tester,
      size: const Size(320, 480),
      textScale: 2,
      library: [
        for (var i = 0; i < 14; i++) entry('r$i', PlatformId.reddit, MediaKind.video, onDisk: true, title: 'Clip number $i'),
      ],
    );
    double link() => tester
        .state<ScrollableState>(find.descendant(of: find.byType(EditableText), matching: find.byType(Scrollable)))
        .position
        .pixels;
    double strip() => Scrollable.of(tester.element(find.byType(LibraryTile).first)).position.pixels;

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final place = scrolled(tester);
    expect(place, greaterThan(0));
    await tester.drag(find.byType(LibraryTile).first, const Offset(-90, 0));
    await tester.pumpAndSettle();
    final along = strip();
    expect(along, greaterThan(0));
    expect(along, isNot(place));

    controller.goTab(1);
    await tester.pumpAndSettle();
    controller.goTab(0);
    await tester.pump();
    expect(link(), 0, reason: 'the link does not start where the page or the strip was left');
    await tester.pumpAndSettle();
    expect(scrolled(tester), place);
    expect(strip(), along);
  });

  testWidgets('home: one photo gets one save button and singular words', (tester) async {
    final controller = await boot(tester);
    const urls = ['https://example.com/1.jpg'];
    const one = MediaInfo(
      id: 'one',
      title: 'Dinner',
      webpageUrl: 'https://www.tiktok.com/@someone/photo/2',
      platform: PlatformId.tiktok,
      photos: urls,
      options: [QualityOption(id: 'photos', label: 'Photos', ext: 'jpg', kind: MediaKind.photo, photoUrls: urls)],
    );
    controller
      ..media = one
      ..selected = one.options.first
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('TIKTOK · 1 PHOTO'), findsOneWidget);
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Photos'), findsNothing);
    expect(find.text('Save photo'), findsOneWidget);
    expect(find.text('Save photos'), findsNothing);
    expect(find.text('Save this photo'), findsNothing, reason: 'it would save the same file as the button above it');
    expect(find.byTooltip('Next'), findsNothing);
  });

  testWidgets('tabs: each keeps its place on the page while the other is open', (tester) async {
    final controller = await boot(
      tester,
      library: [for (var i = 0; i < 12; i++) entry('k$i', PlatformId.reddit, MediaKind.video, onDisk: true)],
    );
    controller.goTab(1);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final place = scrolled(tester);
    expect(place, greaterThan(0));
    controller.goTab(0);
    await tester.pumpAndSettle();
    expect(scrolled(tester), 0, reason: 'Home has its own place');
    controller.goTab(1);
    await tester.pumpAndSettle();
    expect(scrolled(tester), place);
  });

  testWidgets('home: a new post opens at its top, wherever the page was', (tester) async {
    final controller = await boot(
      tester,
      size: const Size(320, 480),
      textScale: 2,
      library: [entry('k', PlatformId.reddit, MediaKind.video, onDisk: true)],
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(scrolled(tester), greaterThan(0));

    controller
      ..media = sampleVideo
      ..selected = sampleVideo.options.first
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(scrolled(tester), 0);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final place = scrolled(tester);
    expect(place, greaterThan(0));

    // The same post keeps its place across a visit to the library.
    controller.goTab(1);
    await tester.pumpAndSettle();
    controller.goTab(0);
    await tester.pumpAndSettle();
    expect(scrolled(tester), place);

    final next = pictured('https://example.com/none.jpg', id: 'next');
    controller
      ..media = next
      ..selected = next.options.first
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(scrolled(tester), 0);
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
        entry('a', PlatformId.reddit, MediaKind.video, onDisk: true, title: 'A long English title that cannot fit on the lines a sheet gives it, however it is cut'),
        entry('b', PlatformId.tiktok, MediaKind.video, onDisk: true, title: 'عنوان عربي طويل جدا ما تكفيه السطور اللي تنطيها الورقة مهما انقص'),
      ],
    );
    await tester.tap(tab('التنزيلات'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LibraryTile).at(0));
    await tester.pumpAndSettle();
    final english = tester.widget<Text>(find.textContaining('A long English title'));
    expect(english.textDirection, TextDirection.ltr);
    expect(english.textAlign, TextAlign.right);
    await tester.tapAt(const Offset(180, 40));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LibraryTile).at(1));
    await tester.pumpAndSettle();
    final arabic = tester.widget<Text>(find.textContaining('عنوان عربي'));
    expect(arabic.textDirection, TextDirection.rtl);
    expect(arabic.textAlign, TextAlign.right);
  });

  testWidgets(
    'wide window: a toolbar with the link field, over one page of the post and the library, and no tabs',
    (tester) async {
      final controller = await boot(
        tester,
        size: const Size(1280, 800),
        library: [
          for (var i = 0; i < 6; i++) entry('w$i', PlatformId.values[i], MediaKind.video, onDisk: true),
        ],
      );
      final mark = find.descendant(of: find.byType(WideBar), matching: find.byType(NazzilLogo));
      expect(mark, findsOneWidget);
      expect(logo, findsNothing, reason: 'the phone header is gone');
      expect(find.text('Home'), findsNothing);
      expect(find.text('Recent'), findsNothing, reason: 'the library itself is in view');
      expect(find.text('Paste a link, or press Ctrl+V'), findsOneWidget);
      final field = tester.getRect(find.byType(LinkFrame));
      expect(field.left, greaterThan(tester.getRect(mark).right), reason: 'the link field is in the toolbar');
      expect(field.top, lessThan(tester.getRect(mark).bottom));
      expect(tester.getRect(find.byTooltip('Settings')).left, greaterThan(field.right));

      expect(find.text('6 ITEMS'), findsOneWidget);
      final first = tester.getTopLeft(find.byType(LibraryTile).at(0));
      expect(tester.getTopLeft(find.byType(LibraryTile).at(5)).dy, first.dy, reason: 'six cards share the first row');
      expect(first.dy, greaterThan(field.bottom));
      final title = tester.getRect(find.text('Saved item w0'));
      expect(title.top, greaterThanOrEqualTo(tester.getRect(find.byType(LibraryTile).at(0)).bottom),
          reason: 'a card carries its title under its picture');

      // The button is named for the next step, as on a phone.
      expect(find.widgetWithText(NazzilButton, 'Paste'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'https://www.youtube.com/watch?v=abc');
      await tester.pump();
      expect(find.widgetWithText(NazzilButton, 'Fetch'), findsOneWidget);

      // A fetched post leads the page in one tile, its picture beside its words, the library under it.
      controller
        ..media = sampleVideo
        ..selected = sampleVideo.options.first
        ..fetchedUrl = controller.url
        ..notifyListeners();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(NazzilButton, 'Paste'), findsOneWidget, reason: 'the link of the post on show is no next step');
      final post = find.byType(WidePost);
      final clear = tester.getRect(find.descendant(of: post, matching: find.byTooltip('Clear')));
      final download = tester.getRect(find.text('Download'));
      expect(clear.top, greaterThan(field.bottom));
      expect(download.left, greaterThan(clear.right), reason: 'the words stand beside the picture');
      expect(tester.getTopLeft(find.byType(LibraryTile).at(0)).dy, greaterThan(download.bottom));

      // Esc takes the post off the page, as its close button does.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.media, isNull);
      expect(post, findsNothing);
    },
    variant: linux,
  );

  testWidgets(
    'wide window: an item opens in a dialog, and a right click opens its actions where it was made',
    (tester) async {
      await boot(
        tester,
        size: const Size(1280, 800),
        library: [entry('d', PlatformId.youtube, MediaKind.video, onDisk: true, title: 'A saved clip')],
      );
      await tester.tap(find.text('A saved clip'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);

      final card = tester.getCenter(find.byType(LibraryTile));
      await tester.tapAt(card, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      final menu = find.byType(PopupMenuItem<VoidCallback>);
      expect(menu, findsNWidgets(4), reason: 'play, open the file, the original post and delete');
      final play = tester.getRect(find.descendant(of: menu.first, matching: find.text('Play')));
      expect((play.top - card.dy).abs(), lessThan(48), reason: 'the menu opens where the pointer is');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'a saved file is asked about before it goes');
    },
    variant: linux,
  );

  testWidgets('a window under 720 wide keeps the phone layout', variant: linux, (tester) async {
    await boot(tester, size: const Size(700, 800));
    expect(find.byType(WideBar), findsNothing);
    expect(logo, findsOneWidget);
    expect(tab('Library'), findsOneWidget);
  });

  testWidgets('a phone on its side keeps the phone layout, being too short for a toolbar over the page', (tester) async {
    await boot(tester, size: const Size(844, 390));
    expect(find.byType(WideBar), findsNothing);
    expect(tab('Library'), findsOneWidget);
  });

  testWidgets('done dialog: colour crosses the picture once, not at all under reduce motion, and the title counts the photos', (tester) async {
    final shown = await picture(tester, 'shown', 80, 60);
    Widget dialog({bool photos = false, bool onePhoto = false}) => MaterialApp(
          theme: NazzilTheme.dark(arabic: false),
          home: Scaffold(
            body: DoneSheet(
              s: const S('en'),
              photos: photos,
              onePhoto: onePhoto,
              cover: Image.file(File(shown), fit: BoxFit.cover),
              ghost: Image.file(File(shown), fit: BoxFit.cover),
              onView: () {},
              onShare: () {},
              onClose: () {},
            ),
          ),
        );
    await tester.pumpWidget(dialog());
    await tester.pump(const Duration(milliseconds: 350));
    final crossing = tester.widget<ArrivalFrame>(find.byType(ArrivalFrame)).arrived;
    expect(crossing, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(tester.widget<ArrivalFrame>(find.byType(ArrivalFrame)).arrived, 1);
    expect(find.byType(ColorFiltered), findsNothing, reason: 'it ends in full colour');
    expect(find.text('Saved'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Close'), findsOneWidget);

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(dialog());
    expect(find.byType(ArrivalFrame), findsNothing);
    expect(find.byType(Image), findsOneWidget);

    // The title counts: one photo is not "Photos".
    await tester.pumpWidget(dialog(photos: true, onePhoto: true));
    expect(find.text('Photo saved'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'View'), findsOneWidget);
    await tester.pumpWidget(dialog(photos: true));
    expect(find.text('Photos saved'), findsOneWidget);
  });

  testWidgets('done dialog: a finished download opens it over the app, and Close puts it away', (tester) async {
    final controller = await boot(
      tester,
      library: [entry('clip', PlatformId.reddit, MediaKind.video, onDisk: true)],
    );
    controller
      ..doneItem = controller.library.first
      ..notifyListeners();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget, reason: 'a phone has a share sheet');
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    expect(controller.doneItem, isNull);
  });

  testWidgets('done dialog: a tap that lands on Download as the download ends gets the Saved dialog alone', (tester) async {
    final key = LinkParser.identityKey(sampleVideo.webpageUrl, sampleVideo.id);
    final controller = await boot(
      tester,
      library: [entry('abc', PlatformId.youtube, MediaKind.video, onDisk: true, videoKey: key)],
    );
    controller
      ..media = sampleVideo
      ..selected = sampleVideo.options.first
      // The download has just ended: Download is back on the page, and the dialog is not up yet.
      ..doneItem = controller.library.first
      ..notifyListeners();
    await controller.download();
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('You already have this'), findsNothing, reason: 'the Saved dialog says as much');

    // With that dialog put away, Download answers that the file is there.
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    expect(find.text('You already have this'), findsOneWidget);
  });

  testWidgets('accessibility guidelines: tap targets, labels and text contrast', (tester) async {
    final handle = tester.ensureSemantics();
    final shown = await picture(tester, 'shown', 300, 200, color: const Color(0xFFE8E0D0));
    for (final (theme, language) in [
      ('dark', 'en'),
      ('light', 'en'),
      ('dark', 'ar'),
      ('light', 'ar'),
    ]) {
      // A screen tall enough to show each page whole: text cut by the edge
      // of a scroll area gets measured against whatever sits beside it.
      final controller = await boot(
        tester,
        theme: theme,
        language: language,
        size: const Size(360, 2400),
        // Two pixels a point, as on a phone: at one, thin letters never reach their own colour.
        pixelRatio: 2,
        library: [
          entry('a', PlatformId.reddit, MediaKind.video, onDisk: true, thumbnail: shown),
          entry('b', PlatformId.x, MediaKind.video, status: LibraryItem.statusFailed, error: Failure.blocked.name),
          entry('c', PlatformId.tiktok, MediaKind.photo, photoCount: 4),
          entry('d', PlatformId.youtube, MediaKind.audio, status: LibraryItem.statusCancelled),
          entry('e', PlatformId.instagram, MediaKind.video),
        ],
      );
      LocalPictures.serve({'https://pictures.example/photo.png': shown});
      Future<void> check(String where) async {
        final at = '$where, $theme $language';
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: at);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline), reason: at);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: at);
        // Flutter's own contrast check draws the page at one pixel a point
        // whatever the screen and takes the most common light shade for the
        // text colour: on thin letters that is the blur at their edge.
        final contrast = await measureContrast(tester);
        expect(contrast.faint, isEmpty, reason: at);
        expect(contrast.checked, greaterThan(3), reason: at);
        debugPrint('contrast $at: ${contrast.checked} texts and icons, lowest ${contrast.lowest.toStringAsFixed(2)}:1');
      }

      await pictures(tester);
      controller
        ..clipOffer = 'https://www.tiktok.com/@someone/video/1'
        ..failure = Failure.noLink
        ..notifyListeners();
      await tester.pumpAndSettle();
      await check('home');

      controller.setUrl('https://www.tiktok.com/@someone/video/7301112223334445556');
      await tester.pumpAndSettle();
      await check('home with a link');

      final media = pictured('https://pictures.example/photo.png');
      controller
        ..clipOffer = null
        ..media = media
        ..selected = media.options.first
        ..failure = Failure.network
        ..notifyListeners();
      await tester.pump();
      await pictures(tester);
      await check('home result');

      final job = jobFor(media, LibraryItem.statusDownloading);
      controller
        ..failure = Failure.none
        ..library = [job, ...controller.library]
        ..activeJobId = job.id
        ..downloading = true
        ..progress = 0.5
        ..notifyListeners();
      await tester.pumpAndSettle();
      await check('home downloading');
      controller
        ..downloading = false
        ..activeJobId = null
        ..library = [jobFor(media, LibraryItem.statusPaused), ...controller.library.skip(1)]
        ..notifyListeners();
      await tester.pumpAndSettle();
      await check('home paused');

      controller.goTab(1);
      await tester.pumpAndSettle();
      await pictures(tester);
      await check('library');
      await tester.tap(find.text(controller.s.filterAllApps));
      await tester.pumpAndSettle();
      await check('app menu');
      await tester.tapAt(const Offset(180, 2000));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(LibraryTile).at(1));
      await tester.pumpAndSettle();
      await pictures(tester);
      await check('item sheet');
      await tester.tap(find.text(controller.s.delete));
      await tester.pumpAndSettle();
      await check('delete dialog');
      await tester.tap(find.text(controller.s.cancel));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(LibraryTile).at(2));
      await tester.pumpAndSettle();
      await check('item sheet of a failed download');
      await tester.tapAt(const Offset(180, 40));
      await tester.pumpAndSettle();

      controller
        ..doneItem = controller.library[1]
        ..notifyListeners();
      await tester.pump();
      await tester.pumpAndSettle();
      await check('done dialog');
      await tester.tap(find.text(controller.s.close));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(controller.s.settings));
      await tester.pumpAndSettle();
      await check('settings');
      await tester.pumpWidget(const SizedBox());
    }
    handle.dispose();
  });

  testWidgets('the contrast measure itself: faint, unseen and faded words are caught, plain ones pass', (tester) async {
    tester.view.physicalSize = const Size(720, 800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const style = TextStyle(fontFamily: NazzilTheme.sans, fontSize: 15, decoration: TextDecoration.none);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFF202020),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('plain', style: style.copyWith(color: const Color(0xFFFFFFFF))),
              Text('faint', style: style.copyWith(color: const Color(0xFF505050))),
              Text('unseen', style: style.copyWith(color: const Color(0xFF202020))),
              Opacity(opacity: 0.25, child: Text('faded', style: style.copyWith(color: const Color(0xFFFFFFFF)))),
              Text.rich(
                TextSpan(
                  style: style.copyWith(color: const Color(0xFFFFFFFF)),
                  children: const [
                    TextSpan(text: 'two '),
                    TextSpan(text: 'tone', style: TextStyle(color: Color(0xFF606060))),
                  ],
                ),
              ),
              const Icon(Icons.settings_outlined, color: Color(0xFF3A3A3A)),
            ],
          ),
        ),
      ),
    );
    final contrast = await measureContrast(tester);
    expect(contrast.checked, 7);
    expect(contrast.faint, hasLength(5));
    expect(contrast.faint[0], allOf(startsWith('"faint" is 2.02:1'), isNot(contains('painted at'))));
    expect(contrast.faint[1], startsWith('"unseen" is 1.00:1'));
    expect(contrast.faint[2], allOf(startsWith('"faded" is '), contains('painted at 25% of')));
    expect(contrast.faint[3], startsWith('"tone" is 2.59:1'));
    expect(contrast.faint[4], startsWith('icon is 1.43:1, needs 3.0'));
    expect(contrast.lowest, closeTo(1, 0.001));
  });

  testWidgets('keyboard: tab reaches the controls and shows a focus ring', (tester) async {
    final controller = await boot(tester, size: const Size(800, 900));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);

    // The segmented control rings the focused segment from inside its edge, in
    // two tones; the inner band, four wide, counts one ring per focused segment.
    int rings() => tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .where((decoration) => decoration.border?.top.width == 4)
        .length;

    // One stop for the back button, then three languages and three themes;
    // the last stop is the System theme.
    var ringed = 0;
    for (var i = 0; i < 7; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      if (rings() == 1) ringed++;
    }
    expect(ringed, 6);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.settings.theme, 'system');
  });

  testWidgets('keyboard: a picture on the wall shows a ring inside its edge, and Enter opens it', (tester) async {
    final controller = await boot(
      tester,
      library: [entry('k', PlatformId.reddit, MediaKind.video, onDisk: true, title: 'Kept clip')],
    );
    controller.goTab(1);
    await tester.pumpAndSettle();
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    final tile = tester.getRect(find.byType(LibraryTile));
    int ringed() => tester
        .widgetList<DecoratedBox>(find.descendant(of: find.byType(LibraryTile), matching: find.byType(DecoratedBox)))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .where((decoration) => decoration.border != null)
        .length;
    expect(ringed(), 0);
    for (var i = 0; i < 12 && !tile.contains(FocusManager.instance.primaryFocus!.rect.center); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    expect(tile.contains(FocusManager.instance.primaryFocus!.rect.center), isTrue);
    expect(ringed(), 2, reason: 'two tones, so the ring shows on a light picture and on a dark one');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Kept clip'), findsOneWidget);
  });

  testWidgets('keyboard: tab walks the empty Home from the header down to the tabs', (tester) async {
    await boot(tester, library: [entry('k', PlatformId.reddit, MediaKind.video, onDisk: true)]);
    final stops = <String, Finder>{
      'Settings': find.byTooltip('Settings'),
      'Link': find.byType(EditableText),
      'Paste': find.text('Paste'),
      'To library': find.widgetWithText(TextButton, 'Library'),
      'Tile': find.byType(LibraryTile),
      'Home': tab('Home'),
      'Library': tab('Library'),
    };
    final walked = <String>[];
    for (var i = 0; i < 8; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final rect = FocusManager.instance.primaryFocus!.rect;
      walked.add(
        stops.entries.where((stop) => rect.contains(tester.getCenter(stop.value))).map((stop) => stop.key).join('+'),
      );
    }
    expect(walked, ['Settings', 'Link', 'Paste', 'To library', 'Tile', 'Home', 'Library', 'Settings']);
  });

  for (final wide in [false, true]) {
    testWidgets(
      'keyboard: tab walks the page before the tabs, and the toolbar before the page (${wide ? 'wide' : 'phone'})',
      (tester) async {
        // On a phone the tabs come last; on a wide window the toolbar comes first, then the post, then the library.
        final size = wide ? const Size(1280, 800) : const Size(360, 720);
        final controller = await boot(
          tester,
          size: size,
          library: [entry('k', PlatformId.reddit, MediaKind.video, onDisk: true)],
        );
        controller
          ..media = sampleVideo
          ..selected = sampleVideo.options.first
          ..notifyListeners();
        await tester.pumpAndSettle();

        final stops = <String, Finder>{
          'Link': find.byType(EditableText),
          'Paste': find.widgetWithText(NazzilButton, 'Paste'),
          'Settings': find.byTooltip('Settings'),
          'Clear': find.byTooltip('Clear'),
          for (final text in ['HD', 'SD', 'Audio', 'Download', 'Home', 'Library', 'All']) text: find.text(text),
        };
        String focused() {
          final rect = FocusManager.instance.primaryFocus!.rect;
          return stops.entries
              .where((stop) => stop.value.evaluate().isNotEmpty && rect.contains(tester.getCenter(stop.value.first)))
              .map((stop) => stop.key)
              .join('+');
        }

        final walked = <String>[];
        for (var i = 0; i < 24; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          walked.add(focused());
          // The window itself listens for the paste shortcut and has no ring to show.
          expect(FocusManager.instance.primaryFocus!.size, isNot(size), reason: 'stop $i at $size is the whole window');
        }
        final page = ['Clear', 'HD', 'SD', 'Audio', 'Download'];
        if (wide) {
          expect(walked.take(9), ['Link', 'Paste', 'Settings', ...page, 'All']);
          expect(walked.where((stop) => stop == 'Settings').length, greaterThan(1), reason: 'the round closes');
        } else {
          // The poster stands where the header was, so its way out is the first stop.
          expect(walked.take(8), [...page, 'Home', 'Library', 'Clear']);
        }
      },
      variant: wide ? linux : TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
