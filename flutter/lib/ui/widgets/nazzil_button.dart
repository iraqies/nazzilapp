import 'package:flutter/material.dart';

import '../../theme/nazzil_theme.dart';

class NazzilButton extends StatelessWidget {
  const NazzilButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.progress,
    this.icon,
    this.tint,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final double? progress;
  final IconData? icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? NazzilColors.rose;
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
          padding: EdgeInsets.zero,
          elevation: 0,
          shadowColor: color.withValues(alpha: 0.4),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (progress != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: progress!.clamp(0, 1),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
            Center(
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                        ],
                        Text(label),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
