import 'package:flutter/material.dart';

import '../../theme/nazzil_theme.dart';

class PlatformPills extends StatelessWidget {
  const PlatformPills({super.key});

  static const _items = [
    ('YouTube', Color(0xFFFF4D4D)),
    ('TikTok', NazzilColors.rose),
    ('Instagram', Color(0xFFE1306C)),
    ('Facebook', Color(0xFF4B8BFF)),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in _items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: item.$2.withValues(alpha: 0.35)),
            ),
            child: Text(
              item.$1,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
      ],
    );
  }
}
