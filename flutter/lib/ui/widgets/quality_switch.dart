import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/media.dart';
import 'choice_row.dart';

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

  @override
  Widget build(BuildContext context) {
    return ChoiceRow<String>(
      value: selected?.id,
      options: [for (final option in options) (option.id, _label(option))],
      onChanged: (id) => onSelect(options.firstWhere((option) => option.id == id)),
    );
  }
}
