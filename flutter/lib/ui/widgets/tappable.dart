import 'package:flutter/material.dart';

import '../../theme/nazzil_theme.dart';

/// A tap target for controls built from scratch: hover and pressed ink, plus
/// a ring just outside its edge while it holds keyboard focus.
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
  final String? label;
  final bool? selected;

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool _ring = false;

  @override
  Widget build(BuildContext context) {
    final OutlinedBorder shape = widget.circle
        ? CircleBorder(side: widget.side)
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.radius), side: widget.side);
    final ring = BorderSide(
      color: widget.ringColor ?? Theme.of(context).colorScheme.onSurface,
      width: 2,
      strokeAlign: BorderSide.strokeAlignOutside,
    );
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      selected: widget.selected,
      label: widget.label,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(shape: shape.copyWith(side: _ring ? ring : BorderSide.none)),
        child: Material(
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
        ),
      ),
    );
  }
}
