import 'package:flutter/material.dart';

import '../../theme/nazzil_theme.dart';

class NazzilButton extends StatelessWidget {
  const NazzilButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  /// The quieter of two buttons: an outline, so the fill stays on the main action.
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final quiet = WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? scheme.onSurfaceVariant : scheme.onSurface,
    );
    // The button that does the next step glows in its own blue, as Finery's does.
    final lit = !secondary && !busy && onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NazzilRadius.control),
        boxShadow: lit ? NazzilTheme.glow : null,
      ),
      child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: secondary
            ? ButtonStyle(
                backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
                foregroundColor: quiet,
                iconColor: quiet,
                overlayColor: WidgetStatePropertyAll(scheme.onSurface.withValues(alpha: 0.1)),
                shape: WidgetStateProperty.resolveWith(
                  (states) => RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(NazzilRadius.control),
                    side: states.contains(WidgetState.focused)
                        ? BorderSide(color: scheme.onSurface, width: 2, strokeAlign: BorderSide.strokeAlignOutside)
                        : BorderSide(color: scheme.outline, width: 1.5),
                  ),
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 10),
              ] else if (icon != null) ...[
                Icon(icon),
                const SizedBox(width: 8),
              ],
              // A busy button says so aloud: its new words are not read out otherwise.
              Flexible(
                child: Semantics(liveRegion: busy, child: Text(label, textAlign: TextAlign.center)),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
