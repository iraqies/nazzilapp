import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';

/// The empty frame on Home. It asks for a link, and it is the link field:
/// tapping it lets the user type one or edit the one in it. It fills the
/// height it is given, and is never shorter than [minHeight] or its own words.
class LinkFrame extends StatefulWidget {
  const LinkFrame({super.key, required this.controller, required this.s, required this.minHeight});
  final NazzilController controller;
  final S s;
  final double minHeight;

  @override
  State<LinkFrame> createState() => _LinkFrameState();
}

class _LinkFrameState extends State<LinkFrame> {
  late final TextEditingController _text;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.controller.url);
    widget.controller.addListener(_sync);
    _focus.addListener(_repaint);
    _text.addListener(_repaint);
  }

  void _sync() {
    final url = widget.controller.url;
    if (_text.text != url) {
      _text.value = TextEditingValue(text: url, selection: TextSelection.collapsed(offset: url.length));
    }
  }

  void _repaint() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = _text.text.isEmpty;
    final focused = _focus.hasFocus;
    final asking = empty && !focused;
    final label = theme.textTheme.labelMedium!;
    // The link starts under its label, however large the system font is.
    final labelHeight = MediaQuery.textScalerOf(context).scale(label.fontSize!) * label.height!;
    return CustomPaint(
      foregroundPainter: _FramePainter(
        color: focused ? scheme.onSurface : scheme.outline,
        width: focused ? 2 : 1.5,
        dashed: !focused,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: widget.minHeight),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // It keeps its place when hidden, so the frame does not change size under the finger.
            Visibility(
              visible: asking,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.content_paste_rounded, size: 32, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 10),
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: Text(
                        s.framePrompt,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(s.frameHint, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            if (!asking)
              PositionedDirectional(
                top: 14,
                start: 16,
                end: 16,
                child: ExcludeSemantics(child: Text(s.linkLabel, maxLines: 1, style: label)),
              ),
            // The field is as tall as its text; a tap anywhere else in the frame reaches it too.
            Positioned.fill(
              child: MouseRegion(
                cursor: SystemMouseCursors.text,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: _focus.requestFocus,
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Semantics(
                label: s.linkLabel,
                child: TextField(
                  // A long link scrolls inside the frame. Named, that place is not the page's.
                  key: const PageStorageKey('link'),
                  controller: _text,
                  focusNode: _focus,
                  onChanged: widget.controller.setUrl,
                  onSubmitted: (_) => widget.controller.fetch(),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  autocorrect: false,
                  maxLines: null,
                  // A link reads left to right in the Arabic app too, on the lines Latin is set on.
                  textDirection: TextDirection.ltr,
                  style: NazzilTheme.inScript(theme.textTheme.bodyLarge!, arabic: false),
                  decoration: InputDecoration(
                    hintText: asking ? null : s.pasteHint,
                    hintMaxLines: 8,
                    hintTextDirection: Directionality.of(context),
                    contentPadding: EdgeInsetsDirectional.fromSTEB(16, 14 + labelHeight + 6, 16, empty ? 16 : 52),
                  ),
                ),
              ),
            ),
            if (!empty)
              PositionedDirectional(
                bottom: 2,
                end: 2,
                child: IconButton(
                  tooltip: s.clear,
                  onPressed: widget.controller.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({required this.color, required this.width, required this.dashed});
  final Color color;
  final double width;
  final bool dashed;

  static const _dash = 6.0;
  static const _gap = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(width / 2),
      const Radius.circular(NazzilRadius.control),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    if (!dashed) {
      canvas.drawRRect(frame, paint);
      return;
    }
    for (final metric in (Path()..addRRect(frame)).computeMetrics()) {
      // A whole number of dashes, so the last one meets the first.
      final count = (metric.length / (_dash + _gap)).round();
      final step = metric.length / count;
      for (var i = 0; i < count; i++) {
        canvas.drawPath(metric.extractPath(i * step, i * step + step * _dash / (_dash + _gap)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.width != width || oldDelegate.dashed != dashed;
}
