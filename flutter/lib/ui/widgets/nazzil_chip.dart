import 'package:flutter/material.dart';

import 'tappable.dart';

/// One choice among a few: the picked one takes the brand fill, the rest
/// keep an outline that marks them as pressable.
class NazzilChip extends StatelessWidget {
  const NazzilChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Tappable(
      onTap: onTap,
      selected: selected,
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      side: BorderSide(color: selected ? scheme.primary : scheme.outline, width: selected ? 1.5 : 1),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: ink),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
