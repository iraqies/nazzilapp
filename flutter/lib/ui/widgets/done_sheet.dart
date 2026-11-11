import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import 'arriving.dart';
import 'nazzil_button.dart';

/// The dialog a finished download opens. Its picture goes from grey to
/// colour once: the same move the download made, played to the end.
class DoneSheet extends StatelessWidget {
  const DoneSheet({
    super.key,
    required this.s,
    required this.photos,
    required this.onView,
    required this.onClose,
    this.onePhoto = false,
    this.onShare,
    this.cover,
    this.ghost,
  });

  final S s;
  final bool photos;

  /// True when a single photo was saved, not an album.
  final bool onePhoto;
  final VoidCallback onView;
  final VoidCallback onClose;

  /// Null where the system cannot share a file.
  final VoidCallback? onShare;

  /// The picture of what was saved, and the same picture bare, as [ArrivingPicture] takes them.
  final Widget? cover;
  final Widget? ghost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = this.cover;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cover != null)
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ExcludeSemantics(
                    child: ColoredBox(
                      color: theme.colorScheme.surfaceContainerHigh,
                      child: ColourSweep(ghost: ghost ?? cover, child: cover),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: Text(
                        photos ? (onePhoto ? s.photoSaved : s.albumSaved) : s.downloaded,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    NazzilButton(
                      label: photos ? s.view : s.play,
                      icon: photos ? Icons.photo_outlined : Icons.play_arrow_rounded,
                      onPressed: onView,
                    ),
                    if (onShare != null) ...[
                      const SizedBox(height: 8),
                      NazzilButton(
                        label: s.share,
                        icon: Icons.ios_share_rounded,
                        secondary: true,
                        onPressed: onShare,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Center(child: TextButton(onPressed: onClose, child: Text(s.close))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
