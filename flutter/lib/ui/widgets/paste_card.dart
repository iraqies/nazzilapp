import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/strings.dart';
import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';

class PasteCard extends StatefulWidget {
  const PasteCard({super.key, required this.controller, required this.s});
  final NazzilController controller;
  final S s;

  @override
  State<PasteCard> createState() => _PasteCardState();
}

class _PasteCardState extends State<PasteCard> {
  late final TextEditingController _text;
  late final VoidCallback _sync;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.controller.url);
    _sync = () {
      if (_text.text != widget.controller.url) {
        _text.value = TextEditingValue(
          text: widget.controller.url,
          selection: TextSelection.collapsed(offset: widget.controller.url.length),
        );
      }
    };
    widget.controller.addListener(_sync);
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(NazzilRadius.card),
        border: Border.all(color: _focus.hasFocus ? scheme.onSurface : scheme.outline, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: Text(s.linkLabel, style: theme.textTheme.labelMedium)),
                  Semantics(
                    label: s.linkLabel,
                    child: TextField(
                      controller: _text,
                      focusNode: _focus,
                      onChanged: widget.controller.setUrl,
                      onSubmitted: (_) => widget.controller.fetch(),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      autocorrect: false,
                      minLines: 2,
                      maxLines: 4,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(hintText: s.pasteHint, hintMaxLines: 4),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    await widget.controller.paste(data?.text ?? '');
                  },
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: Text(s.paste),
                ),
                if (widget.controller.url.isNotEmpty)
                  TextButton(
                    onPressed: widget.controller.clear,
                    child: Text(s.clear),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
