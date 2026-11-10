import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../theme/nazzil_theme.dart';

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
    _pages = PageController(viewportFraction: 0.86, initialPage: widget.index);
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
    final glide = NazzilMotion.of(context, const Duration(milliseconds: 280));
    return Column(
      children: [
        SizedBox(
          height: 380,
          child: PageView.builder(
            controller: _pages,
            itemCount: widget.urls.length,
            onPageChanged: widget.onChanged,
            itemBuilder: (context, i) {
              final active = i == widget.index;
              return AnimatedScale(
                duration: glide,
                curve: Curves.easeOutCubic,
                scale: active ? 1 : 0.9,
                child: AnimatedOpacity(
                  duration: glide,
                  opacity: active ? 1 : 0.55,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(NazzilRadius.card),
                      child: ColoredBox(
                        color: scheme.surfaceContainerHigh,
                        child: CachedNetworkImage(
                          imageUrl: widget.urls[i],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (_, _, _) => Center(
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
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${widget.index + 1} ${widget.s.ofWord} ${widget.urls.length}',
          style: theme.textTheme.labelMedium,
        ),
      ],
    );
  }
}
