import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tappable.dart';
import 'title_text.dart';

/// A row of choices as one iOS segmented control: a filled track with the
/// picked segment raised on a thumb. Segments share the width evenly and
/// their labels shrink to fit, so the control never overflows its row.
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

  static const _trackRadius = 11.0;
  static const _thumbRadius = 9.0;
  static const _inset = 2.0;
  // A segment is its own tap target, so it clears the 48 the guidelines ask for.
  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final track = dark ? const Color(0xFF2C2C2E) : const Color(0xFFEEEEF0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(_trackRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_inset),
        child: Row(
          children: [
            for (final option in options) Expanded(child: _segment(context, option, dark)),
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, (T, String) option, bool dark) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = value == option.$1;
    final thumb = dark ? const Color(0xFF636366) : Colors.white;
    final style = styleIn(option.$2, theme.textTheme.labelLarge!, Directionality.of(context)).copyWith(
      color: scheme.onSurface,
      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
    );
    // The picked thumb sits a little proud of the track, as iOS draws it.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_thumbRadius),
        boxShadow: active && !dark
            ? const [
                BoxShadow(color: Color(0x1F000000), offset: Offset(0, 3), blurRadius: 7),
                BoxShadow(color: Color(0x0A000000), offset: Offset(0, 3), blurRadius: 1),
              ]
            : null,
      ),
      child: Tappable(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(option.$1);
        },
        selected: active,
        radius: _thumbRadius,
        ringInside: true,
        color: active ? thumb : Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _height),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(option.$2, maxLines: 1, style: style),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
