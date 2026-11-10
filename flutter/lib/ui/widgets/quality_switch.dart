import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/media.dart';
import '../../theme/nazzil_theme.dart';

class QualitySwitch extends StatelessWidget {
  const QualitySwitch({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.s,
  });

  final List<QualityOption> options;
  final QualityOption? selected;
  final ValueChanged<QualityOption> onSelect;
  final S s;

  String _label(QualityOption option) {
    return switch (option.label) {
      'HD' => s.hd,
      'SD' => s.sd,
      'Audio' => s.audio,
      'Photos' => s.photos,
      'Album' => s.album,
      'Video' => s.video,
      _ => option.label,
    };
  }

  IconData _icon(QualityOption option) {
    return switch (option.kind) {
      MediaKind.photo => Icons.photo_library_outlined,
      MediaKind.audio => Icons.graphic_eq_rounded,
      MediaKind.video when option.photoUrls.isNotEmpty => Icons.slideshow_outlined,
      MediaKind.video => Icons.hd_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          Builder(
            builder: (context) {
              final active = option.id == selected?.id;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                child: Material(
                  color: active
                      ? (option.kind == MediaKind.photo
                          ? NazzilColors.lilac
                          : NazzilColors.rose)
                      : scheme.surfaceContainerLow,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: active
                          ? Colors.transparent
                          : scheme.outline,
                    ),
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onSelect(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _icon(option),
                            size: 16,
                            color: active ? Colors.white : scheme.onSurface,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _label(option),
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: active ? Colors.white : scheme.onSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
