import 'package:flutter/material.dart';

import 'logo_outline.g.dart';

/// The Nazzil logo: the name, written in the Ruqaa hand. The letters take the
/// text colour, and the dots and the shadda are Grape.
/// It is the same in both languages, as a logo is.
class NazzilLogo extends StatelessWidget {
  const NazzilLogo({super.key, required this.height, required this.name, this.letters});

  final double height;

  /// The name as a screen reader says it.
  final String name;

  /// The colour of the letters where they stand on a ground of their own, as on
  /// the icon; elsewhere they take the text colour.
  final Color? letters;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: name,
      image: true,
      child: CustomPaint(
        size: Size(height * LogoOutline.width / LogoOutline.height, height),
        painter: _LogoPainter(letters: letters ?? scheme.onSurface, dots: scheme.primaryContainer),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.letters, required this.dots});
  final Color letters;
  final Color dots;

  static final _letters = _outline(LogoOutline.letters);
  static final _dots = _outline(LogoOutline.dots);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / LogoOutline.height;
    canvas
      ..save()
      ..scale(scale)
      ..translate(-LogoOutline.left, -LogoOutline.top)
      ..drawPath(_letters, Paint()..color = letters)
      ..drawPath(_dots, Paint()..color = dots)
      ..restore();
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => oldDelegate.letters != letters || oldDelegate.dots != dots;
}

/// Reads outlines as the logo's exporter writes them: M, L, H, V, Q and Z, each followed by positions on the page.
Path _outline(String data) {
  final path = Path();
  var x = 0.0;
  var y = 0.0;
  for (final step in RegExp('([MLHVQZ])([^MLHVQZ]*)').allMatches(data)) {
    final n = [for (final number in RegExp(r'-?[\d.]+').allMatches(step[2]!)) double.parse(number[0]!)];
    switch (step[1]) {
      case 'M':
        path.moveTo(x = n[0], y = n[1]);
      case 'L':
        path.lineTo(x = n[0], y = n[1]);
      case 'H':
        path.lineTo(x = n[0], y);
      case 'V':
        path.lineTo(x, y = n[0]);
      case 'Q':
        path.quadraticBezierTo(n[0], n[1], x = n[2], y = n[3]);
      case 'Z':
        path.close();
    }
  }
  return path;
}
