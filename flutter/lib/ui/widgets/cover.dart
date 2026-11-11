import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/media.dart';
import '../../theme/nazzil_theme.dart';

/// Where a poster is cut when its frame is shorter than the picture: a third
/// of the way down, since faces and titles sit above the middle.
const posterAlignment = Alignment(0, -0.3);

IconData kindIcon(MediaKind kind) => switch (kind) {
      MediaKind.photo => Icons.image_rounded,
      MediaKind.audio => Icons.graphic_eq_rounded,
      MediaKind.video => Icons.videocam_rounded,
    };

/// A picture from the web that fills its box. [bare] leaves out what stands
/// in for it while it loads or after it fails, for a copy drawn over another.
class NetPicture extends StatelessWidget {
  const NetPicture({
    super.key,
    required this.url,
    this.alignment = Alignment.center,
    this.loading,
    this.failed,
    this.bare = false,
  });

  final String url;
  final Alignment alignment;
  final Widget? loading;
  final Widget? failed;
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final loading = bare ? null : this.loading;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: NazzilMotion.of(context),
      fadeOutDuration: NazzilMotion.of(context),
      placeholder: loading == null ? null : (_, _) => loading,
      errorWidget: (_, _, _) => (bare ? null : failed) ?? const SizedBox.shrink(),
    );
  }
}

/// The picture that stands for a library item, filling whatever box it gets.
class Cover extends StatelessWidget {
  const Cover({super.key, required this.item, required this.extent, this.bare = false});

  final LibraryItem item;

  /// The longer side of the box, so no more of the picture is decoded than it needs.
  final double extent;

  /// The picture alone: nothing at all where there is none to show.
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget fallback = bare
        ? const SizedBox.shrink()
        : Center(child: Icon(kindIcon(item.kind), color: scheme.onSurfaceVariant));
    // A full-size photo per tile would fill the memory.
    final side = (extent * MediaQuery.devicePixelRatioOf(context) * 1.5).round();
    Widget fromFile(File file, Widget Function() otherwise) => Image(
          image: ResizeImage(FileImage(file), width: side, height: side, policy: ResizeImagePolicy.fit),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => otherwise(),
        );
    final thumb = item.thumbnail;
    final online = thumb != null && thumb.startsWith('http');
    final thumbFile = thumb != null && !online && File(thumb).existsSync() ? File(thumb) : null;
    Widget fromThumb() {
      if (online) return NetPicture(url: thumb, failed: fallback, bare: bare);
      return thumbFile == null ? fallback : fromFile(thumbFile, () => fallback);
    }

    final first = item.paths.isEmpty ? null : File(item.paths.first);
    final saved = first != null && first.existsSync();
    // A saved photo is its own cover: sharper than the site's thumbnail, and there offline.
    if (saved && item.kind == MediaKind.photo) return fromFile(first, fromThumb);
    if (online || thumbFile != null) return fromThumb();
    // An album saved as a video can still open on a photo.
    return saved ? fromFile(first, () => fallback) : fallback;
  }
}
