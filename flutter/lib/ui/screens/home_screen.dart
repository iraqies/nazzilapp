import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/strings.dart';
import '../../models/media.dart';
import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';
import '../widgets/arriving.dart';
import '../widgets/cover.dart';
import '../widgets/item_sheet.dart';
import '../widgets/library_tile.dart';
import '../widgets/link_frame.dart';
import '../widgets/nazzil_button.dart';
import '../widgets/page_stepper.dart';
import '../widgets/photo_film.dart';
import '../widgets/quality_switch.dart';
import '../widgets/title_text.dart';
import '../widgets/top_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller, required this.onSettings, this.wide = false});
  final NazzilController controller;
  final VoidCallback onSettings;

  /// Beside the library on a wide window: the shell draws the header, and
  /// the strip of last saves goes, since the library itself is in view.
  final bool wide;

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    await controller.paste(data?.text ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final media = controller.media;
    final inset = wide ? 0.0 : MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        Expanded(
          child: Padding(
            // The poster of a fetched post runs under the status bar; all else starts below it.
            padding: EdgeInsets.only(top: media == null ? inset : 0),
            child: LayoutBuilder(
              builder: (context, constraints) => CustomScrollView(
                // The key keeps the place on the page while the other tab is open,
                // and a new post gets a new key, so it opens at its top.
                key: PageStorageKey('home ${media?.webpageUrl ?? ''}'),
                slivers: media == null
                    ? _asking(context, constraints.biggest)
                    : _fetched(context, media, constraints.biggest, inset),
              ),
            ),
          ),
        ),
        if (controller.clipOffer != null) _ClipOffer(controller: controller, s: s),
      ],
    );
  }

  List<Widget> _asking(BuildContext context, Size body) {
    final s = controller.s;
    final typed = controller.url.trim().isNotEmpty;
    final recent = wide ? const <LibraryItem>[] : controller.library.take(12).toList();
    return [
      // One screenful when there is room: the frame takes what the rest leaves,
      // so the button and the last saves stay at the bottom, near the thumb.
      SliverFillRemaining(
        hasScrollBody: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!wide) TopBar(controller: controller, onSettings: onSettings),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, wide ? 20 : 12, 20, 0),
                // Never flatter than a film frame.
                child: LinkFrame(controller: controller, s: s, minHeight: (body.width - 40) * 9 / 16),
              ),
            ),
            FocusTraversalGroup(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // One button, named for the next step: Paste into an empty frame, Fetch once it holds a link.
                    NazzilButton(
                      label: controller.loading ? s.fetching : (typed ? s.fetch : s.paste),
                      icon: typed ? null : Icons.content_paste_rounded,
                      busy: controller.loading,
                      onPressed: typed ? () => controller.fetch() : _paste,
                    ),
                    if (controller.loading)
                      Center(
                        child: TextButton.icon(
                          onPressed: controller.cancelFetch,
                          icon: const Icon(Icons.close_rounded),
                          label: Text(s.cancel),
                        ),
                      ),
                    if (controller.error.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _ErrorLine(controller.error),
                    ],
                    const SizedBox(height: 16),
                    _Apps(s: s),
                  ],
                ),
              ),
            ),
            if (recent.isEmpty)
              const SizedBox(height: 28)
            else
              Padding(
                padding: const EdgeInsets.only(top: 28, bottom: 24),
                child: FocusTraversalGroup(child: _Recent(controller: controller, items: recent)),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _fetched(BuildContext context, MediaInfo media, Size body, double inset) {
    final photos = controller.selected?.kind == MediaKind.photo ||
        (media.isPhotoAlbum && controller.selected == null);
    final album = photos && media.photos.length > 1;
    // Saving one photo of an album is a job of its own, shown while that photo is up.
    final job = controller.jobForCurrent() ??
        (album ? controller.jobForCurrent(onlyPhoto: controller.photoIndex) : null);
    final running = job != null && job.id == controller.activeJobId;
    final arriving = running && job.status == LibraryItem.statusDownloading && !controller.converting;
    return [
      _Poster(
        // A new post, or the same post turned from its video to its photos, starts a new frame.
        key: ValueKey('${media.webpageUrl} $photos'),
        controller: controller,
        media: media,
        photos: photos,
        body: body,
        below: _Result.heightFor(context, media, body.width - 40, album: album) + 12,
        inset: inset,
        progress: arriving ? controller.progress : null,
        unsaved: job != null && !arriving && !(running && controller.converting),
      ),
      SliverToBoxAdapter(
        child: FocusTraversalGroup(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: _Result(controller: controller, media: media, photos: photos, job: job, live: !wide),
          ),
        ),
      ),
    ];
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    // The icon marks it as an error where words alone would rest on the red.
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2, end: 8),
            child: Icon(Icons.error_outline_rounded, size: 18, color: error),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: error))),
        ],
      ),
    );
  }
}

/// The apps a link can come from, as a quiet line under the button.
class _Apps extends StatelessWidget {
  const _Apps({required this.s});
  final S s;

  @override
  Widget build(BuildContext context) {
    final names = [
      for (final platform in PlatformId.values)
        if (platform != PlatformId.unknown) s.platformName(platform),
    ];
    final style = Theme.of(context).textTheme.labelMedium!;
    final layout = Directionality.of(context);
    return Semantics(
      label: names.join(', '),
      child: ExcludeSemantics(
        child: Center(
          child: FractionallySizedBox(
            widthFactor: 0.78,
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 2,
              children: [for (final name in names) Text(name, style: styleIn(name, style, layout))],
            ),
          ),
        ),
      ),
    );
  }
}

/// The last saves, as a strip of frames along the bottom of Home.
class _Recent extends StatelessWidget {
  const _Recent({required this.controller, required this.items});
  final NazzilController controller;
  final List<LibraryItem> items;

  static const _width = 108.0;
  static const _height = 162.0;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 20, end: 8),
          // With large text the way to the library goes under the heading, not into it.
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(header: true, child: Text(s.recent, style: theme.textTheme.titleMedium)),
              TextButton.icon(
                onPressed: () => controller.goTab(1),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded),
                label: Text(s.library),
              ),
            ],
          ),
        ),
        SizedBox(
          height: _height,
          child: ListView.separated(
            // Its own place: unnamed, it would share the one the page keeps and each would move the other.
            key: const PageStorageKey('recent'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 2),
            itemBuilder: (context, index) {
              final item = items[index];
              final running = item.id == controller.activeJobId;
              return SizedBox(
                width: _width,
                child: LibraryTile(
                  item: item,
                  s: s,
                  kept: controller.libraryStore.stillHave(item),
                  progress: running ? controller.progress : null,
                  converting: running && controller.converting,
                  onOpen: () => showItemSheet(context, controller, item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The picture of the fetched post, from the top edge of the screen. It takes
/// the shape of the picture once that is known, and shows the download on it.
class _Poster extends StatefulWidget {
  const _Poster({
    super.key,
    required this.controller,
    required this.media,
    required this.photos,
    required this.body,
    required this.below,
    required this.inset,
    required this.progress,
    required this.unsaved,
  });

  final NazzilController controller;
  final MediaInfo media;
  final bool photos;

  /// The room Home has, which caps the height of the poster.
  final Size body;

  /// How much of that room the words and controls under the poster need.
  final double below;

  /// The height of the status bar the poster runs under, or 0.
  final double inset;
  final double? progress;
  final bool unsaved;

  @override
  State<_Poster> createState() => _PosterState();
}

class _PosterState extends State<_Poster> {
  double? _aspect;
  ImageStream? _stream;
  late final _listener = ImageStreamListener(_measured, onError: (_, _) {});

  /// The picture that gives the frame its shape: the first photo, or the video's thumbnail.
  String? get _url => widget.photos ? widget.media.photos.firstOrNull : widget.media.thumbnail;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream != null) return;
    final url = _url;
    if (url == null || url.isEmpty) return;
    _stream = CachedNetworkImageProvider(url).resolve(createLocalImageConfiguration(context))
      ..addListener(_listener);
  }

  void _measured(ImageInfo info, bool _) {
    final aspect = info.image.width / info.image.height;
    info.dispose();
    if (mounted && aspect != _aspect) setState(() => _aspect = aspect);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.body.width;
    // Never flatter than a film frame, and never so tall that the controls leave the screen.
    final least = width * 9 / 16;
    final most = math.max(least, math.min(widget.body.height - widget.below, widget.body.height * 0.62));
    final height = (width / (_aspect ?? 16 / 10)).clamp(least, most);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: height),
      duration: NazzilMotion.of(context, NazzilMotion.reshape),
      curve: Curves.easeOutCubic,
      child: _picture(context),
      builder: (context, extent, picture) => SliverPersistentHeader(
        pinned: widget.inset > 0,
        delegate: _PosterDelegate(
          extent: extent,
          inset: widget.inset,
          picture: picture!,
          pictured: (_url ?? '').isNotEmpty,
        ),
      ),
    );
  }

  Widget _picture(BuildContext context) {
    final controller = widget.controller;
    final media = widget.media;
    final s = controller.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = widget.progress;
    final thumbnail = media.thumbnail;
    final Widget stand = Center(child: Icon(Icons.videocam_outlined, size: 42, color: scheme.onSurfaceVariant));
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: scheme.surfaceContainerHigh,
          child: widget.photos
              ? PhotoFilm(
                  urls: media.photos,
                  index: controller.photoIndex,
                  onChanged: controller.setPhotoIndex,
                  s: s,
                  progress: progress,
                  unsaved: widget.unsaved,
                )
              : thumbnail == null || thumbnail.isEmpty
                  ? stand
                  : ArrivingPicture(
                      progress: progress,
                      unsaved: widget.unsaved,
                      ghost: NetPicture(url: thumbnail, alignment: posterAlignment, bare: true),
                      child: NetPicture(url: thumbnail, alignment: posterAlignment, loading: stand, failed: stand),
                    ),
        ),
        PositionedDirectional(
          top: widget.inset + 6,
          start: 12,
          child: IconButton(
            tooltip: s.clear,
            onPressed: controller.clear,
            style: ButtonStyle(
              backgroundColor: const WidgetStatePropertyAll(NazzilColors.screen),
              foregroundColor: const WidgetStatePropertyAll(NazzilColors.onScreen),
              overlayColor: WidgetStatePropertyAll(NazzilColors.onScreen.withValues(alpha: 0.14)),
              // Round like the disc it sits on, so hover, press and the focus ring follow the edge.
              shape: WidgetStateProperty.resolveWith(
                (states) => CircleBorder(
                  side: states.contains(WidgetState.focused)
                      ? const BorderSide(
                          color: NazzilColors.onScreen,
                          width: 2,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        )
                      : BorderSide.none,
                ),
              ),
            ),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        if (progress != null)
          PositionedDirectional(
            bottom: 0,
            start: 0,
            // On a block of the page colour, the number reads the same over any picture.
            child: ColoredBox(
              color: scheme.surface,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 16, 0),
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Text(
                    '${(progress * 100).round()}%',
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.displayLarge,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PosterDelegate extends SliverPersistentHeaderDelegate {
  const _PosterDelegate({
    required this.extent,
    required this.inset,
    required this.picture,
    required this.pictured,
  });
  final double extent;
  final double inset;
  final Widget picture;

  /// Whether the post has a picture. A plain block in its place needs no fade
  /// under the status bar, and takes the clock in the colour of the theme.
  final bool pictured;

  @override
  double get maxExtent => math.max(extent, inset);

  /// What stays when the page is scrolled: a strip under the status bar, so
  /// the words of the page never pass behind the clock.
  @override
  double get minExtent => inset;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final page = theme.colorScheme.surface;
    // Over the last stretch the strip turns from picture to page.
    final closed = inset <= 0 ? 0.0 : ((shrinkOffset - (maxExtent - inset - 48)) / 48).clamp(0.0, 1.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: NazzilTheme.overlay(theme.brightness, page, onPicture: pictured && closed < 0.5),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The picture keeps its full height and leaves by the top, as the page under it does.
          ClipRect(
            child: OverflowBox(
              alignment: Alignment.bottomCenter,
              minHeight: maxExtent,
              maxHeight: maxExtent,
              child: picture,
            ),
          ),
          if (inset > 0 && pictured)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: inset + 28,
              // The one gradient in the app: it keeps the clock and battery readable over a bright picture.
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
          if (closed > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: inset,
              child: IgnorePointer(child: ColoredBox(color: page.withValues(alpha: closed))),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_PosterDelegate oldDelegate) =>
      oldDelegate.extent != extent ||
      oldDelegate.inset != inset ||
      oldDelegate.picture != picture ||
      oldDelegate.pictured != pictured;
}

class _Result extends StatelessWidget {
  const _Result({
    required this.controller,
    required this.media,
    required this.photos,
    required this.job,
    required this.live,
  });

  final NazzilController controller;
  final MediaInfo media;
  final bool photos;

  /// The download of this post that is waiting, running or paused, if any.
  final LibraryItem? job;

  /// Whether the status line speaks for itself: on a phone no header is up to do it.
  final bool live;

  /// How tall this stands for [media] in a column [width] wide, from its first line
  /// down to the line that pauses and cancels a download. It adds up what [build]
  /// lays out, at its tallest, so the poster can keep one height whatever the
  /// download is doing.
  static double heightFor(BuildContext context, MediaInfo media, double width, {required bool album}) {
    final theme = Theme.of(context);
    final type = theme.textTheme;
    final layout = Directionality.of(context);
    // A screen gives a line a whole number of pixels, so the height of one is asked, not worked out.
    double tall(String text, TextStyle style, {TextScaler? scaler, int lines = 1}) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: directionOf(text) ?? layout,
        textScaler: scaler ?? MediaQuery.textScalerOf(context),
        maxLines: lines,
      )..layout(maxWidth: width);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    double line(TextStyle style) => tall(' ', style);
    final titleHeight = tall(
      media.title,
      styleIn(media.title, type.headlineMedium!, layout),
      scaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
      lines: 3,
    );
    final author = media.author;
    final button = theme.filledButtonTheme.style?.textStyle?.resolve(const {});
    // An album's first line also holds the buttons that turn its pages.
    return math.max(line(type.bodySmall!), album ? 48 : 0) +
        4 +
        titleHeight +
        (author == null ? 0 : 6 + tall(author, styleIn(author, type.bodySmall!, layout))) +
        16 +
        math.max(48, line(type.labelLarge!) + 16) +
        16 +
        math.max(56, button == null ? 0 : line(button) + 24) +
        4 +
        48;
  }

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final theme = Theme.of(context);
    final job = this.job;
    final mixed = media.options.any((o) => o.label == 'Album');
    // One photo needs one button: "all" and "this one" would save the same file.
    final single = photos && media.photos.length == 1;
    final album = photos && !single;
    final downloading = job?.status == LibraryItem.statusDownloading;
    final converting = downloading && controller.converting;
    final duration = media.duration;
    final facts = [
      s.platformName(media.platform),
      if (photos)
        mixed ? s.itemsN(media.photos.length) : s.photosN(media.photos.length)
      else if (duration != null && duration > 0)
        s.clock(duration),
    ].where((fact) => fact.isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            if (facts.isNotEmpty) Text(facts, style: theme.textTheme.bodySmall),
            if (album)
              PageStepper(
                index: controller.photoIndex,
                count: media.photos.length,
                onStep: controller.setPhotoIndex,
                s: s,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: TitleText(media.title, maxLines: 3, style: theme.textTheme.headlineMedium),
          ),
        ),
        if (media.author != null) ...[
          const SizedBox(height: 6),
          TitleText(media.author!, maxLines: 1, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 16),
        QualitySwitch(
          options: media.options,
          selected: controller.selected,
          onSelect: controller.select,
          s: s,
        ),
        const SizedBox(height: 16),
        if (job == null) ...[
          NazzilButton(
            label: photos ? (single ? s.saveOnePhoto : (mixed ? s.saveAll : s.savePhotos)) : s.download,
            icon: photos
                ? (single ? Icons.photo_outlined : Icons.photo_library_outlined)
                : Icons.download_rounded,
            onPressed: controller.selected == null ? null : () => controller.download(),
          ),
          if (album)
            Center(
              child: TextButton.icon(
                onPressed: () => controller.download(onlyPhoto: controller.photoIndex),
                icon: const Icon(Icons.photo_outlined),
                label: Text(mixed ? s.saveThis : s.savePhoto),
              ),
            ),
        ] else ...[
          if (job.paused) ...[
            NazzilButton(
              label: s.resume,
              icon: Icons.play_arrow_rounded,
              onPressed: () => controller.resumeJob(job),
            ),
            const SizedBox(height: 4),
          ],
          // While it downloads, the percentage is on the poster and this line holds the ways to stop.
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Semantics(
                    liveRegion: live,
                    child: Text(
                      job.paused
                          ? s.paused
                          : converting
                              ? s.converting
                              : downloading
                                  ? s.downloading
                                  : s.queued,
                      // Lighter than the two ways to stop beside it, which are the things to press.
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  if (downloading && !converting)
                    TextButton.icon(
                      onPressed: () => controller.pauseJob(job),
                      icon: const Icon(Icons.pause_rounded),
                      label: Text(s.pause),
                    ),
                  TextButton.icon(
                    onPressed: () => controller.cancelJob(job),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(s.cancel),
                  ),
                ],
              ),
            ],
          ),
        ],
        if (controller.error.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ErrorLine(controller.error),
        ],
      ],
    );
  }
}

/// A link Nazzil found on the clipboard, offered along the bottom of Home.
class _ClipOffer extends StatelessWidget {
  const _ClipOffer({required this.controller, required this.s});
  final NazzilController controller;
  final S s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final words = Text(s.clipOffer, style: theme.textTheme.bodyMedium);
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(onPressed: controller.acceptClipOffer, child: Text(s.fetchThis)),
        const SizedBox(width: 2),
        IconButton(
          tooltip: s.close,
          onPressed: controller.dismissClipOffer,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 6, 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Side by side while the words keep a readable column; with large text, one above the other.
            final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
            if (constraints.maxWidth / scale >= 300) {
              return Row(
                children: [
                  Expanded(child: words),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 8, end: 14),
                  child: words,
                ),
                Align(alignment: AlignmentDirectional.centerEnd, child: actions),
              ],
            );
          },
        ),
      ),
    );
  }
}
