import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/media.dart';
import '../../theme/nazzil_theme.dart';

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
    this.progress,
  });

  final LibraryItem item;
  final S s;
  final bool kept;
  final VoidCallback onOpen;
  final VoidCallback? onCancel;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: item.kind == MediaKind.photo ? 0.78 : 0.86,
          child: Material(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpen,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _cover(),
                  if (item.isAlbum) const _AlbumShine(),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Row(
                      children: [
                        _chip(
                          item.kind == MediaKind.photo ? s.photos : item.platform.name,
                          item.kind == MediaKind.photo ? NazzilColors.lilac : NazzilColors.rose,
                        ),
                        const Spacer(),
                        if (item.photoCount > 1)
                          _chip('${item.photoCount}', NazzilColors.lilac),
                      ],
                    ),
                  ),
                  if (item.status == LibraryItem.statusQueued ||
                      item.status == LibraryItem.statusDownloading ||
                      item.status == LibraryItem.statusPaused)
                    ColoredBox(
                      color: Colors.black45,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.status == LibraryItem.statusDownloading)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    color: NazzilColors.rose,
                                    backgroundColor: Colors.white24,
                                  ),
                                ),
                              Text(
                                item.status == LibraryItem.statusDownloading
                                    ? s.downloading
                                    : item.status == LibraryItem.statusPaused
                                        ? s.paused
                                        : s.queued,
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              Wrap(
                                alignment: WrapAlignment.center,
                                children: [
                                  if (onPause != null && item.status == LibraryItem.statusDownloading)
                                    TextButton(
                                      onPressed: onPause,
                                      child: Text(s.pause, style: const TextStyle(color: Colors.white)),
                                    ),
                                  if (onResume != null && item.status == LibraryItem.statusPaused)
                                    TextButton(
                                      onPressed: onResume,
                                      child: Text(s.resume, style: const TextStyle(color: Colors.white)),
                                    ),
                                  if (onCancel != null)
                                    TextButton(
                                      onPressed: onCancel,
                                      child: Text(s.cancel, style: const TextStyle(color: Colors.white)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (item.status == LibraryItem.statusFailed ||
                      item.status == LibraryItem.statusCancelled)
                    ColoredBox(
                      color: Colors.black45,
                      child: Center(
                        child: Text(
                          item.status == LibraryItem.statusCancelled ? s.cancelled : s.downloadFailed,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else if (!kept && item.done)
                    ColoredBox(
                      color: Colors.black45,
                      child: Center(
                        child: Text(
                          s.missingFile,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _cover() {
    final thumb = item.thumbnail;
    if (thumb != null && thumb.startsWith('http')) {
      return CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover);
    }
    if (thumb != null && File(thumb).existsSync()) {
      return Image.file(File(thumb), fit: BoxFit.cover);
    }
    if (item.paths.isNotEmpty && File(item.paths.first).existsSync()) {
      return Image.file(File(item.paths.first), fit: BoxFit.cover);
    }
    return Center(child: Icon(Icons.movie_outlined, color: NazzilColors.rose));
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _AlbumShine extends StatelessWidget {
  const _AlbumShine();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topRight,
        child: Transform.rotate(
          angle: math.pi / 22,
          child: Container(
            margin: const EdgeInsets.only(top: 16, right: 12),
            width: 42,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
              color: Colors.white10,
            ),
          ),
        ),
      ),
    );
  }
}
