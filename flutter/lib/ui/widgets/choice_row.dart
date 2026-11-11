import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tappable.dart';
import 'title_text.dart';

/// A few choices side by side. The picked one is filled with the text colour,
/// which leaves Grape to the button that does the next step.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T? value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  static const _gap = 8.0;
  static const _labelPad = 12.0;
  static const _minCell = 64.0;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        // The width each cell needs for its label at the current text size.
        final needs = [
          for (final option in options)
            () {
              final painter = TextPainter(
                text: TextSpan(text: option.$2, style: styleIn(option.$2, style, direction)),
                textDirection: direction,
                textScaler: scaler,
                maxLines: 1,
              )..layout();
              final width = painter.width;
              painter.dispose();
              return (width + _labelPad * 2).clamp(_minCell, double.infinity);
            }(),
        ];
        final room = constraints.maxWidth - _gap * (options.length - 1);
        final cell = room / options.length;
        final spare = room - needs.fold(0.0, (sum, need) => sum + need);
        if (options.length > 1 && needs.every((need) => need <= cell)) {
          // Equal cells, while every label fits in one.
          return Row(
            spacing: _gap,
            children: [for (final option in options) Expanded(child: _cell(context, option, style, stretch: true))],
          );
        }
        if (options.length > 1 && spare >= 0) {
          // Still one line: each cell as wide as its label, with the spare room shared out.
          return Row(
            spacing: _gap,
            children: [
              for (final (index, option) in options.indexed)
                SizedBox(
                  width: needs[index] + spare / options.length,
                  child: _cell(context, option, style, stretch: true),
                ),
            ],
          );
        }
        return SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [for (final option in options) _cell(context, option, style, stretch: false)],
          ),
        );
      },
    );
  }

  Widget _cell(BuildContext context, (T, String) option, TextStyle style, {required bool stretch}) {
    final scheme = Theme.of(context).colorScheme;
    final active = value == option.$1;
    return Tappable(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(option.$1);
      },
      selected: active,
      color: active ? scheme.primary : Colors.transparent,
      side: BorderSide(color: active ? scheme.primary : scheme.outline, width: 1.5),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: _minCell),
        child: Align(
          widthFactor: stretch ? null : 1,
          heightFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _labelPad, vertical: 8),
            child: Text(
              option.$2,
              textAlign: TextAlign.center,
              // A language is named in its own letters, in the typeface those letters are set in.
              style: styleIn(option.$2, style, Directionality.of(context))
                  .copyWith(color: active ? scheme.onPrimary : scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
