import 'package:flutter/material.dart';

import '../../theme/nazzil_theme.dart';

class GlowBackdrop extends StatelessWidget {
  const GlowBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = NazzilColors.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [NazzilColors.ink, palette.tint(NazzilColors.ink, 0.06), NazzilColors.ink]
              : [NazzilColors.paper, palette.tint(Colors.white, 0.12), palette.accentTint(const Color(0xFFF6F5F8), 0.08)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -50,
            child: _Blob(color: palette.primary.withValues(alpha: 0.33), size: 260),
          ),
          Positioned(
            bottom: 80,
            left: -70,
            child: _Blob(color: palette.accent.withValues(alpha: 0.2), size: 240),
          ),
          if (!dark)
            Positioned(
              top: 180,
              left: 40,
              child: _Blob(color: palette.primary.withValues(alpha: 0.13), size: 160),
            ),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class Mark extends StatelessWidget {
  const Mark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [NazzilColors.palette.tint(NazzilColors.ink, 0.15), NazzilColors.palette.tint(NazzilColors.ink, 0.05)]
              : [NazzilColors.palette.tint(Colors.white, 0.15), NazzilColors.palette.tint(Colors.white, 0.3)],
        ),
        boxShadow: [
          BoxShadow(
            color: NazzilColors.rose.withValues(alpha: dark ? 0.22 : 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        'N',
        style: TextStyle(
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w800,
          fontSize: size * 0.52,
          color: NazzilColors.rose,
          height: 1,
        ),
      ),
    );
  }
}
