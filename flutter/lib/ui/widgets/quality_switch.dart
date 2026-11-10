import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/media.dart';
import 'nazzil_chip.dart';

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
      'Photos' => option.photoUrls.length == 1 ? s.photo : s.photos,
      'Album' => s.album,
      'Video' => s.video,
      _ => option.label,
    };
  }

  IconData _icon(QualityOption option) {
    return switch (option.kind) {
      MediaKind.photo => option.photoUrls.length == 1 ? Icons.photo_outlined : Icons.photo_library_outlined,
      MediaKind.audio => Icons.graphic_eq_rounded,
      MediaKind.video when option.photoUrls.isNotEmpty => Icons.slideshow_outlined,
      MediaKind.video when option.label == 'HD' => Icons.hd_outlined,
      MediaKind.video when option.label == 'SD' => Icons.sd_outlined,
      MediaKind.video => Icons.videocam_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          NazzilChip(
            label: _label(option),
            icon: _icon(option),
            selected: option.id == selected?.id,
            onTap: () => onSelect(option),
          ),
      ],
    );
  }
}
