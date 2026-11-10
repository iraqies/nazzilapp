import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/media.dart';
import '../../theme/nazzil_theme.dart';
import 'tappable.dart';

class LibraryTile extends StatelessWidget {
  const LibraryTile({
    super.key,
    required this.item,
    required this.s,
    required this.kept,
    required this.onOpen,
    this.onCancel,
    this.onPause,
    this.onResume,
    this.onRetry,
    this.progress,
  });

  final LibraryItem item;
  final S s;
  final bool kept;
  final VoidCallback onOpen;
  final VoidCallback? onCancel;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onRetry;
  final double? progress;

  static const coverRatio = 0.8;
  static const _gap = 8.0;

  /// Height of a tile [width] wide: the cover plus two title lines at the
  /// current text size, so large system fonts get the room they need.
  static double heightFor(BuildContext context, double width) {
    final style = Theme.of(context).textTheme.titleMedium!;
    final line = MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;
    return width / coverRatio + _gap + (line * 2).ceilToDouble() + 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = item.active;
    final stopped = item.status == LibraryItem.statusFailed || item.status == LibraryItem.statusCancelled;
    final missing = !kept && item.done;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: constraints.maxWidth / coverRatio,
              child: Tappable(
                onTap: onOpen,
                label: item.title,
                radius: NazzilRadius.card,
                color: theme.colorScheme.surfaceContainerHigh,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _cover(context),
                    if (busy || stopped || missing)
                      ColoredBox(
                        color: NazzilColors.photoScrim,
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(8),
                            child: busy ? _busy(context) : _stopped(context, missing: missing),
                          ),
                        ),
                      )
                    else
                      PositionedDirectional(
                        top: 8,
                        start: 8,
                        end: 8,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _chip(context, s.platformName(item.platform), icon: _kindIcon),
                            if (item.photoCount > 1) _chip(context, s.photosN(item.photoCount)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: _gap),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData get _kindIcon => switch (item.kind) {
        MediaKind.photo => Icons.photo_outlined,
        MediaKind.audio => Icons.graphic_eq_rounded,
        MediaKind.video => Icons.videocam_outlined,
      };

  Widget _busy(BuildContext context) {
    final label = Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white);
    final white = TextButton.styleFrom(foregroundColor: Colors.white);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.status == LibraryItem.statusDownloading)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(
              value: progress,
              color: Colors.white,
              backgroundColor: Colors.white30,
            ),
          ),
        Text(
          item.status == LibraryItem.statusDownloading
              ? s.downloading
              : item.status == LibraryItem.statusPaused
                  ? s.paused
                  : s.queued,
          style: label,
          textAlign: TextAlign.center,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            if (onPause != null && item.status == LibraryItem.statusDownloading)
              TextButton(onPressed: onPause, style: white, child: Text(s.pause)),
            if (onResume != null && item.status == LibraryItem.statusPaused)
              TextButton(onPressed: onResume, style: white, child: Text(s.resume)),
            if (onCancel != null) TextButton(onPressed: onCancel, style: white, child: Text(s.cancel)),
          ],
        ),
      ],
    );
  }

  Widget _stopped(BuildContext context, {required bool missing}) {
    final label = Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white);
    final text = missing
        ? s.missingFile
        : item.status == LibraryItem.statusCancelled
            ? s.cancelled
            : item.error.isEmpty
                ? s.downloadFailed
                : s.failure(Failure.named(item.error));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: label, textAlign: TextAlign.center),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text(missing ? s.downloadAgain : s.retry, textAlign: TextAlign.center),
          ),
      ],
    );
  }

  Widget _cover(BuildContext context) {
    final fallback = Center(
      child: Icon(_kindIcon, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
    final thumb = item.thumbnail;
    if (thumb != null && thumb.startsWith('http')) {
      return CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover, errorWidget: (_, _, _) => fallback);
    }
    if (thumb != null && File(thumb).existsSync()) {
      return Image.file(File(thumb), fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
    }
    if (item.paths.isNotEmpty && File(item.paths.first).existsSync()) {
      return Image.file(File(item.paths.first), fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
    }
    return fallback;
  }

  Widget _chip(BuildContext context, String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: NazzilColors.photoScrim,
        borderRadius: BorderRadius.circular(NazzilRadius.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
