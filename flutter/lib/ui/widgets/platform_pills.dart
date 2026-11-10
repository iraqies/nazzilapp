import 'package:flutter/material.dart';

class PlatformPills extends StatelessWidget {
  const PlatformPills({super.key});

  static const _items = [
    ('YouTube', Color(0xFFFF4D4D)),
    ('TikTok', Color(0xFFFF4D8D)),
    ('Instagram', Color(0xFFE1306C)),
    ('Facebook', Color(0xFF4B8BFF)),
    ('Reddit', Color(0xFFFF4500)),
    ('X', Color(0xFF8E8E93)),
    ('Pinterest', Color(0xFFE60023)),
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
