import 'package:flutter/material.dart';

import '../../theme/nazzil_theme.dart';

class Mark extends StatelessWidget {
  const Mark({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(NazzilRadius.control),
        ),
        child: Text(
          'N',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w800,
            fontVariations: const [FontVariation('wght', 800)],
            fontSize: size * 0.56,
            color: scheme.onPrimaryContainer,
            height: 1,
          ),
        ),
      ),
    );
  }
}
