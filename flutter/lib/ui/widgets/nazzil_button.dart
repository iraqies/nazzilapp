import 'package:flutter/material.dart';

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

  /// The quieter of two buttons; the brand fill stays on the main action.
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final quiet = WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? scheme.onSurfaceVariant : scheme.onSurface,
    );
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: secondary
            ? ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
                foregroundColor: quiet,
                iconColor: quiet,
                overlayColor: WidgetStatePropertyAll(scheme.onSurface.withValues(alpha: 0.08)),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 10),
              ] else if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          ),
        ),
      ),
    );
  }
}
