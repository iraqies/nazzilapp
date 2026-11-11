import 'package:flutter/material.dart';

import '../../theme/nazzil_theme.dart';

/// A tap target for controls built from scratch: hover and pressed ink, plus
/// a ring while it holds keyboard focus.
class Tappable extends StatefulWidget {
  const Tappable({
    super.key,
    required this.onTap,
    required this.child,
    this.color,
    this.radius = NazzilRadius.control,
    this.circle = false,
    this.side = BorderSide.none,
    this.ringColor,
    this.ringInside = false,
    this.label,
    this.selected,
  });

  final VoidCallback? onTap;
  final Widget child;
  final Color? color;
  final double radius;
  final bool circle;
  final BorderSide side;
  final Color? ringColor;

  /// Draws the ring inside the edge, for a picture that touches its neighbours.
  /// It is two-tone, so it shows on a light picture and on a dark one.
  final bool ringInside;
  final String? label;
  final bool? selected;

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool _ring = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final OutlinedBorder shape = widget.circle
        ? CircleBorder(side: widget.side)
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.radius), side: widget.side);
    final ringColor = widget.ringColor ?? scheme.onSurface;
    final ring = BorderSide(color: ringColor, width: 2, strokeAlign: BorderSide.strokeAlignOutside);
    Widget body = Material(
      color: widget.color ?? Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      animationDuration: Duration.zero,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (focused) {
          // A tap can leave focus behind; only keyboard travel earns the ring.
          final keyboard = FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
          setState(() => _ring = focused && keyboard);
        },
        child: widget.child,
      ),
    );
    if (widget.ringInside) {
      // Both boxes stay in the tree with or without the ring, so the focus they wrap is kept.
      body = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(border: _ring ? Border.all(color: scheme.surface, width: 2) : null),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(border: _ring ? Border.all(color: ringColor, width: 4) : null),
          child: body,
        ),
      );
    } else {
      body = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(shape: shape.copyWith(side: _ring ? ring : BorderSide.none)),
        child: body,
      );
    }
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      selected: widget.selected,
      label: widget.label,
      child: body,
    );
  }
}
