import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../theme/nazzil_theme.dart';
import 'cover.dart';

/// The photos of a post, one to a page and edge to edge. A swipe turns the
/// page, and so does a change of [index] from the buttons beside it.
class PhotoFilm extends StatefulWidget {
  const PhotoFilm({
    super.key,
    required this.urls,
    required this.index,
    required this.onChanged,
    required this.s,
  });

  final List<String> urls;
  final int index;
  final ValueChanged<int> onChanged;
  final S s;

  @override
  State<PhotoFilm> createState() => _PhotoFilmState();
}

class _PhotoFilmState extends State<PhotoFilm> {
  late final PageController _pages;

  @override
  void initState() {
    super.initState();
    // The page is [index] and nothing else. Left to keep its own place, it would come back on the
    // photo it was last left on while the count and Save this photo meant the first one.
    _pages = PageController(initialPage: widget.index, keepPage: false);
  }

  @override
  void didUpdateWidget(covariant PhotoFilm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index &&
        _pages.hasClients &&
        _pages.page?.round() != widget.index) {
      if (NazzilMotion.reduced(context)) {
        _pages.jumpToPage(widget.index);
      } else {
        _pages.animateToPage(
          widget.index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PageView.builder(
      controller: _pages,
      itemCount: widget.urls.length,
      onPageChanged: widget.onChanged,
      itemBuilder: (context, i) {
        return ColoredBox(
          color: scheme.surfaceContainerHigh,
          child: NetPicture(
            url: widget.urls[i],
            alignment: posterAlignment,
            loading: const Center(child: CircularProgressIndicator()),
            failed: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.s.photoFailed,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
