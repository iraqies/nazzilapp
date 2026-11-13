import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';

/// The link field on Home: a single rounded iOS-style field that holds the
/// link to fetch. Tapping it anywhere starts typing; a clear button sits at
/// its end once there is something to clear.
class LinkFrame extends StatefulWidget {
  const LinkFrame({super.key, required this.controller, required this.s});
  final NazzilController controller;
  final S s;

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
    return Semantics(
      label: s.linkLabel,
      textField: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(NazzilRadius.control),
          border: Border.all(
            color: focused ? scheme.onSurface : Colors.transparent,
            width: focused ? 2 : 1.5,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
                child: Icon(Icons.link_rounded, size: 22, color: scheme.onSurfaceVariant),
              ),
              Expanded(
                child: TextField(
                  key: const PageStorageKey('link'),
                  controller: _text,
                  focusNode: _focus,
                  onChanged: widget.controller.setUrl,
                  onSubmitted: (_) => widget.controller.fetch(),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  autocorrect: false,
                  maxLines: 1,
                  // A link reads left to right in the Arabic app too.
                  textDirection: TextDirection.ltr,
                  style: NazzilTheme.inScript(theme.textTheme.bodyLarge!, arabic: false),
                  decoration: InputDecoration(
                    isDense: true,
                    // The field fills the row's height, so its tap target clears 48.
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    border: InputBorder.none,
                    hintText: s.framePrompt,
                    hintTextDirection: Directionality.of(context),
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
              if (empty)
                const SizedBox(width: 14)
              else
                IconButton(
                  tooltip: s.clear,
                  onPressed: widget.controller.clear,
                  icon: const Icon(Icons.cancel, size: 20),
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
