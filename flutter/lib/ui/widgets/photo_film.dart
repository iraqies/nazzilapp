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
      _pages.animateToPage(
        widget.index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                scale: active ? 1 : 0.9,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 280),
                  opacity: active ? 1 : 0.55,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: NazzilColors.lilac.withValues(alpha: active ? 0.28 : 0),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(color: scheme.surfaceContainer),
                            CachedNetworkImage(
                              imageUrl: widget.urls[i],
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Center(
                                child: CircularProgressIndicator(color: NazzilColors.lilac),
                              ),
                              errorWidget: (_, _, _) =>
                                  Icon(Icons.photo_outlined, color: NazzilColors.lilac),
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Color(0x66000000)],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: NazzilColors.lilac.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${widget.index + 1}  ${widget.s.ofWord}  ${widget.urls.length}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: NazzilColors.lilac,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
