import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/nazzil_theme.dart';
import 'tappable.dart';

class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  static const _inset = 6.0;
  static const _gap = 4.0;
  static const _labelPad = 10.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelLarge!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(NazzilRadius.card),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_inset),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Equal cells on one line while every label fits at the current
            // text size; otherwise the cells wrap at their own width.
            final cell = (constraints.maxWidth - _gap * (options.length - 1)) / options.length;
            final scaler = MediaQuery.textScalerOf(context);
            final direction = Directionality.of(context);
            final fits = options.every((option) {
              final painter = TextPainter(
                text: TextSpan(text: option.$2, style: style),
                textDirection: direction,
                textScaler: scaler,
                maxLines: 1,
              )..layout();
              final width = painter.width;
              painter.dispose();
              return width + _labelPad * 2 <= cell;
            });
            final cells = [
              for (final option in options) _cell(context, option, style, stretch: fits),
            ];
            if (fits) {
              return Row(spacing: _gap, children: [for (final cell in cells) Expanded(child: cell)]);
            }
            return SizedBox(
              width: double.infinity,
              child: Wrap(spacing: _gap, runSpacing: _gap, children: cells),
            );
          },
        ),
      ),
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
      color: active ? scheme.primaryContainer : Colors.transparent,
      side: active ? BorderSide(color: scheme.primary, width: 1.5) : BorderSide.none,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Align(
          widthFactor: stretch ? null : 1,
          heightFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _labelPad, vertical: 8),
            child: Text(
              option.$2,
              textAlign: TextAlign.center,
              style: style.copyWith(color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}
