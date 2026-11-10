import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../theme/nazzil_theme.dart';
import 'nazzil_button.dart';

class DoneSheet extends StatelessWidget {
  const DoneSheet({
    super.key,
    required this.s,
    required this.photos,
    required this.onView,
    required this.onClose,
    this.onShare,
  });

  final S s;
  final bool photos;
  final VoidCallback onView;
  final VoidCallback onClose;

  /// Null where the system cannot share a file.
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!NazzilMotion.reduced(context)) const ConfettiBurst(),
            Material(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(NazzilRadius.card),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      photos ? s.albumSaved : s.downloaded,
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    NazzilButton(
                      label: photos ? s.view : s.play,
                      icon: photos ? Icons.photo_outlined : Icons.play_arrow_rounded,
                      onPressed: onView,
                    ),
                    if (onShare != null) ...[
                      const SizedBox(height: 10),
                      NazzilButton(
                        label: s.share,
                        icon: Icons.ios_share_rounded,
                        secondary: true,
                        onPressed: onShare,
                      ),
                    ],
                    const SizedBox(height: 4),
                    TextButton(onPressed: onClose, child: Text(s.close)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one celebration in the app: it runs once when a download lands, in
/// the picked colour, and is skipped when the system asks for less motion.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final random = math.Random();
    _pieces = List.generate(48, (i) {
      final angle = (-110 + random.nextDouble() * 40) * math.pi / 180;
      final power = 0.5 + random.nextDouble() * 0.8;
      return _Piece(
        ox: 0.2 + random.nextDouble() * 0.6,
        oy: 0.08 + random.nextDouble() * 0.1,
        vx: math.cos(angle) * power,
        vy: math.sin(angle) * power * 0.3 - (0.4 + random.nextDouble() * 0.4),
        g: 1.3 + random.nextDouble() * 0.6,
        spin: 180 + random.nextDouble() * 520,
        w: 6 + random.nextDouble() * 8,
        h: 4 + random.nextDouble() * 5,
        brand: i % 3 != 0,
        delay: random.nextDouble() * 0.14,
        circle: i % 5 == 0,
      );
    });
    _clock = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..forward();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: SizedBox(
        height: 420,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            return CustomPaint(
              painter: _ConfettiPainter(_pieces, _clock.value, scheme.primaryContainer, scheme.onSurface),
            );
          },
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.ox,
    required this.oy,
    required this.vx,
    required this.vy,
    required this.g,
    required this.spin,
    required this.w,
    required this.h,
    required this.brand,
    required this.delay,
    required this.circle,
  });
  final double ox, oy, vx, vy, g, spin, w, h, delay;
  final bool brand;
  final bool circle;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t, this.brand, this.neutral);
  final List<_Piece> pieces;
  final double t;
  final Color brand;
  final Color neutral;

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final local = ((t - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final x = piece.ox * size.width + piece.vx * local * size.width;
      final y = piece.oy * size.height +
          piece.vy * local * size.height +
          piece.g * local * local * size.height;
      final paint = Paint()..color = (piece.brand ? brand : neutral).withValues(alpha: 1 - local * local);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.spin * local * math.pi / 180);
      if (piece.circle) {
        canvas.drawCircle(Offset.zero, piece.w * 0.4, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: piece.w, height: piece.h),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
