import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/media.dart';
import '../../theme/nazzil_theme.dart';
import 'arriving.dart';
import 'cover.dart';
import 'tappable.dart';
import 'title_text.dart';

/// What a library item is, or what has become of its download, in a few words.
({IconData icon, String text}) itemTag(
  LibraryItem item,
  S s, {
  required bool kept,
  double? progress,
  bool converting = false,
}) {
  if (item.status == LibraryItem.statusDownloading) {
    if (converting) return (icon: Icons.sync_rounded, text: s.converting);
    return (
      icon: Icons.download_rounded,
      text: progress == null ? s.downloading : s.percent((progress * 100).round()),
    );
  }
  if (item.status == LibraryItem.statusQueued) return (icon: Icons.schedule_rounded, text: s.queued);
  if (item.paused) return (icon: Icons.pause_rounded, text: s.paused);
  if (item.status == LibraryItem.statusFailed) {
    return (
      icon: Icons.error_outline_rounded,
      text: item.error.isEmpty ? s.downloadFailed : s.failure(Failure.named(item.error)),
    );
  }
  if (item.status == LibraryItem.statusCancelled) return (icon: Icons.close_rounded, text: s.cancelled);
  if (!kept) return (icon: Icons.folder_off_outlined, text: s.missingFile);
  final duration = item.duration;
  return (
    icon: kindIcon(item.kind),
    text: switch (item.kind) {
      MediaKind.photo => item.photoCount > 1 ? s.photosN(item.photoCount) : s.photo,
      MediaKind.audio => s.audio,
      MediaKind.video => duration != null && duration > 0 ? s.clock(duration) : s.video,
    },
  );
}

/// One frame of the library wall: the picture, and a tag that says what it
/// is or what state it is in. The title and the actions are a tap away.
class LibraryTile extends StatelessWidget {
  const LibraryTile({
    super.key,
    required this.item,
    required this.s,
    required this.kept,
    required this.onOpen,
    this.progress,
    this.converting = false,
  });

  final LibraryItem item;
  final S s;

  /// Whether the saved file is still on the device.
  final bool kept;
  final VoidCallback onOpen;

  /// Set while this item is the one downloading.
  final double? progress;
  final bool converting;

  static const ratio = 3 / 4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tag = itemTag(item, s, kept: kept, progress: progress, converting: converting);
    final arriving = item.status == LibraryItem.statusDownloading && progress != null && !converting;
    final here = (item.done && kept) || (item.status == LibraryItem.statusDownloading && converting);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Tappable(
          onTap: onOpen,
          radius: NazzilRadius.picture,
          ringInside: true,
          label: [item.title, tag.text].where((part) => part.isNotEmpty).join(', '),
          color: scheme.surfaceContainerHigh,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ArrivingPicture(
                progress: arriving ? progress : null,
                unsaved: !arriving && !here,
                ghost: Cover(item: item, extent: constraints.biggest.longestSide, bare: true),
                child: Cover(item: item, extent: constraints.biggest.longestSide),
              ),
              PositionedDirectional(
                start: 6,
                end: 6,
                bottom: 6,
                child: Align(
                  alignment: AlignmentDirectional.bottomStart,
                  // A tag on a picture grows a little with the system font, not all the way.
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.3,
                    child: ExcludeSemantics(child: PictureTag(icon: tag.icon, text: tag.text)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A frame of the library wall with its title and app under it, for a wide
/// window. A pointer's secondary button opens the item's actions where it points.
class LibraryCard extends StatefulWidget {
  const LibraryCard({
    super.key,
    required this.item,
    required this.s,
    required this.kept,
    required this.onOpen,
    required this.onMenu,
    this.progress,
    this.converting = false,
  });

  final LibraryItem item;
  final S s;
  final bool kept;
  final VoidCallback onOpen;
  final ValueChanged<Offset> onMenu;
  final double? progress;
  final bool converting;

  static const _gap = 8.0;

  /// The words grow with the system font as the tag on the picture does, up to 1.3 times.
  static const _scale = 1.3;

  static TextStyle _title(TextTheme type) => type.labelLarge!;

  /// How tall the words under a picture stand, so a grid can give each card its height.
  static double captionHeight(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: _scale);
    double line(TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: ' ', style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    // The two lines the title may take, the app's line, and a pixel in hand for rounding.
    return _gap + 2 * line(_title(type)) + 2 + line(type.labelMedium!) + 1;
  }

  @override
  State<LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<LibraryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final type = Theme.of(context).textTheme;
    final app = widget.s.platformName(item.platform);
    return GestureDetector(
      onSecondaryTapUp: (details) => widget.onMenu(details.globalPosition),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: LibraryTile.ratio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LibraryTile(
                    item: item,
                    s: widget.s,
                    kept: widget.kept,
                    onOpen: widget.onOpen,
                    progress: widget.progress,
                    converting: widget.converting,
                  ),
                  // Ink is drawn under the picture and cannot show, so a pointer over it dims the picture instead.
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _hover ? 1 : 0,
                      duration: NazzilMotion.of(context),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0x1F000000),
                          borderRadius: BorderRadius.circular(NazzilRadius.picture),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: LibraryCard._gap),
            // The picture's label already reads the title out, so the words are only seen.
            ExcludeSemantics(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onOpen,
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: LibraryCard._scale,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TitleText(item.title, maxLines: 2, style: LibraryCard._title(type)),
                        const SizedBox(height: 2),
                        Text(
                          app,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styleIn(app, type.labelMedium!, Directionality.of(context)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White words on a dark scrim, readable over any picture.
class PictureTag extends StatelessWidget {
  const PictureTag({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  /// The words are not set smaller than this share of their size. Past it a long word breaks.
  static const _smallest = 0.7;

  /// A word wider than the line is cut in two wherever the line ends, and on the narrow
  /// frames of Home's strip "Cancelled" is that wide. There the words are set a little smaller.
  TextStyle _fitted(BuildContext context, TextStyle style, double room) {
    final size = style.fontSize;
    if (size == null || !room.isFinite) return style;
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    var widest = 0.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      painter
        ..text = TextSpan(text: word, style: style)
        ..layout();
      if (painter.width > widest) widest = painter.width;
    }
    painter.dispose();
    if (widest <= room) return style;
    // A hair under the exact share, so that rounding does not leave the last letter over.
    return style.copyWith(fontSize: size * (room / widest * 0.98).clamp(_smallest, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: NazzilColors.onPhoto);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NazzilColors.photoScrim,
        borderRadius: BorderRadius.circular(NazzilRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(7, 3, 9, 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 15, color: NazzilColors.onPhoto),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: LayoutBuilder(
                builder: (context, box) => Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: style == null ? null : _fitted(context, style, box.maxWidth),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
