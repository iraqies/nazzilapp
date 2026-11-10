import 'package:flutter/material.dart';

/// The direction a piece of text reads in, taken from its first letter.
/// Null when it has none to go by, as with a bare number or an emoji.
TextDirection? directionOf(String text) {
  for (final rune in text.runes) {
    // Hebrew through Arabic Extended, then the Arabic presentation forms.
    final rtl = (rune >= 0x0590 && rune <= 0x08FF) ||
        (rune >= 0xFB1D && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFC);
    if (rtl) return TextDirection.rtl;
    // Latin, Greek and Cyrillic, the Indic and other scripts up to Greek
    // Extended, then the East Asian blocks.
    final ltr = (rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A) ||
        (rune >= 0xC0 && rune <= 0x058F) ||
        (rune >= 0x0900 && rune <= 0x1FFF) ||
        (rune >= 0x2E80 && rune <= 0xD7FF);
    if (ltr) return TextDirection.ltr;
  }
  return null;
}

/// A title from a post. It reads in its own direction, so an English title
/// is cut at its end in the Arabic app too, and lines up with the layout.
class TitleText extends StatelessWidget {
  const TitleText(this.text, {super.key, this.style, this.maxLines});
  final String text;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final layout = Directionality.of(context);
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      textDirection: directionOf(text) ?? layout,
      textAlign: layout == TextDirection.rtl ? TextAlign.right : TextAlign.left,
    );
  }
}
