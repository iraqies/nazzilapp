import 'package:flutter/material.dart';

import '../../theme/nazzil_theme.dart';

/// A picture that shows how much of its file is on the device: in colour
/// where it has arrived, grey where it is still to come, and a line of the
/// accent at the front. Colour arrives from the side reading starts on.
class ArrivingPicture extends StatelessWidget {
  const ArrivingPicture({
    super.key,
    required this.child,
    required this.ghost,
    this.progress,
    this.unsaved = false,
  });

  final Widget child;

  /// The same picture with nothing around it, to be drawn in grey over
  /// [child]. An icon or a message standing in for the picture stays as it is.
  final Widget ghost;

  /// How much has arrived, from 0 to 1. Null when no download is running.
  final double? progress;

  /// All grey: waiting, paused, failed, cancelled or gone.
  final bool unsaved;

  @override
  Widget build(BuildContext context) {
    final target = unsaved ? 0.0 : (progress ?? 1.0).clamp(0.0, 1.0);
    // The same tree in every state, so the picture is not rebuilt when a
    // download starts or ends, and the colour moves on from where it was.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: target),
      duration: NazzilMotion.of(context, NazzilMotion.arrive),
      builder: (context, arrived, _) => ArrivalFrame(
        arrived: arrived,
        line: !unsaved,
        ghost: ghost,
        child: child,
      ),
    );
  }
}

/// Colour crossing a picture once, from grey to full, when its download lands.
class ColourSweep extends StatelessWidget {
  const ColourSweep({super.key, required this.child, required this.ghost});
  final Widget child;
  final Widget ghost;

  @override
  Widget build(BuildContext context) {
    if (NazzilMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: NazzilMotion.sweep,
      curve: Curves.easeInOutCubic,
      builder: (context, arrived, _) => ArrivalFrame(arrived: arrived, ghost: ghost, child: child),
    );
  }
}

class ArrivalFrame extends StatelessWidget {
  const ArrivalFrame({
    super.key,
    required this.arrived,
    required this.child,
    required this.ghost,
    this.line = true,
  });

  final double arrived;
  final Widget child;
  final Widget ghost;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (arrived < 1)
          ExcludeSemantics(
            child: ClipRect(
              clipper: _Rest(arrived, rtl),
              child: ColorFiltered(colorFilter: NazzilColors.unsaved, child: ghost),
            ),
          ),
        if (line && arrived > 0 && arrived < 1)
          Align(
            alignment: AlignmentDirectional(arrived * 2 - 1, 0),
            child: SizedBox(
              width: 2,
              height: double.infinity,
              child: ColoredBox(color: Theme.of(context).colorScheme.primaryContainer),
            ),
          ),
      ],
    );
  }
}

/// The part of the picture that has not arrived yet.
class _Rest extends CustomClipper<Rect> {
  const _Rest(this.arrived, this.rtl);
  final double arrived;
  final bool rtl;

  @override
  Rect getClip(Size size) => rtl
      ? Rect.fromLTRB(0, 0, size.width * (1 - arrived), size.height)
      : Rect.fromLTRB(size.width * arrived, 0, size.width, size.height);

  @override
  bool shouldReclip(_Rest oldClipper) => oldClipper.arrived != arrived || oldClipper.rtl != rtl;
}
