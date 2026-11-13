import 'package:flutter/material.dart';

import '../../theme/nazzil_theme.dart';
import 'title_text.dart';

/// The big line at the top of a screen. It is already large, so it follows
/// the system font size only part of the way and long words stay whole.
class Heading extends StatelessWidget {
  const Heading(this.text, {super.key, this.textAlign});
  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        header: true,
        child: Text(
          text,
          textAlign: textAlign,
          style: styleIn(text, Theme.of(context).textTheme.displaySmall!, Directionality.of(context)),
        ),
      ),
    );
  }
}

/// The small line over a heading, as Finery sets it: bold and in the accent, and
/// in Latin letters spaced out in capitals. Arabic has no capitals and is never
/// spaced, so its letters stay as they are.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.textAlign});
  final String text;
  final TextAlign? textAlign;

  static bool _arabic(String text, TextDirection layout) => (directionOf(text) ?? layout) == TextDirection.rtl;

  /// The style [text] is set in, for a layout that measures it ahead of time.
  static TextStyle styleOf(BuildContext context, String text) {
    final theme = Theme.of(context);
    final layout = Directionality.of(context);
    final base = theme.textTheme.labelMedium!;
    final style = base.copyWith(
      color: NazzilTheme.link(theme.brightness),
      fontWeight: NazzilTheme.bold,
      letterSpacing: _arabic(text, layout) ? 0 : base.fontSize! * 0.14,
    );
    return styleIn(text, style, layout);
  }

  @override
  Widget build(BuildContext context) {
    final layout = Directionality.of(context);
    return Text(
      _arabic(text, layout) ? text : text.toUpperCase(),
      semanticsLabel: text,
      textAlign: textAlign,
      style: styleOf(context, text),
    );
  }
}
