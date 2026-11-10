import 'package:flutter/material.dart';

import '../../l10n/strings.dart';

/// Previous and next beside the page count, so a mouse or a keyboard can
/// turn the pages a finger would swipe.
class PageStepper extends StatelessWidget {
  const PageStepper({
    super.key,
    required this.index,
    required this.count,
    required this.onStep,
    required this.s,
    this.onPhoto = false,
  });

  final int index;
  final int count;
  final ValueChanged<int> onStep;
  final S s;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = onPhoto ? Colors.white : theme.colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: s.previous,
          color: color,
          disabledColor: color.withValues(alpha: 0.38),
          onPressed: index > 0 ? () => onStep(index - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${index + 1} ${s.ofWord} $count',
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
          ),
        ),
        IconButton(
          tooltip: s.next,
          color: color,
          disabledColor: color.withValues(alpha: 0.38),
          onPressed: index < count - 1 ? () => onStep(index + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
