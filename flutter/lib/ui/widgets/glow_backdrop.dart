import 'package:flutter/material.dart';

import '../../theme/nazzil_theme.dart';

class GlowBackdrop extends StatelessWidget {
  const GlowBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF08060C), Color(0xFF140A16), Color(0xFF08060C)]
              : const [Color(0xFFF7F1F4), Color(0xFFFFE8F0), Color(0xFFF4EEF8)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -90,
            right: -50,
            child: _Blob(color: Color(0x55FF4D8D), size: 260),
          ),
          const Positioned(
            bottom: 80,
            left: -70,
            child: _Blob(color: Color(0x338B7CFF), size: 240),
          ),
          if (!dark)
            const Positioned(
              top: 180,
              left: 40,
              child: _Blob(color: Color(0x22FF4D8D), size: 160),
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
              ? const [Color(0xFF2A121C), Color(0xFF140C12)]
              : const [Color(0xFFFFE0EC), Color(0xFFFFC2D7)],
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
