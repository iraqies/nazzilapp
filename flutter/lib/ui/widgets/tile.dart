import 'package:flutter/material.dart';

import '../../theme/nazzil_theme.dart';
import 'title_text.dart';

/// A Finery tile: a panel rounded wide and lifted off the page by a soft shadow.
/// A showcase tile is lit from above by a faint gradient, for what is on show.
class Tile extends StatelessWidget {
  const Tile({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.showcase = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showcase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(NazzilRadius.card);
    Widget body = Padding(padding: padding, child: child);
    if (showcase) {
      body = DecoratedBox(
        decoration: BoxDecoration(gradient: NazzilTheme.showcase(theme.brightness)),
        child: body,
      );
    }
    // A Material of its own, so the ink of a row inside shows on the tile and not under it.
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: NazzilTheme.tileShadow(theme.brightness)),
      child: Material(
        color: showcase ? Colors.transparent : theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: body,
      ),
    );
  }
}

/// A few words in a pill, as Finery lines its badges up under what is on show.
/// Every badge is alike: no app a link comes from ranks above another.
class PillBadge extends StatelessWidget {
  const PillBadge(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0x14FFFFFF) : const Color(0xD9FFFFFF),
        borderRadius: BorderRadius.circular(NazzilRadius.pill),
        border: Border.all(color: dark ? const Color(0x1AFFFFFF) : const Color(0x0F000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        child: Text(
          text,
          style: styleIn(text, theme.textTheme.labelSmall!, Directionality.of(context))
              .copyWith(color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}
