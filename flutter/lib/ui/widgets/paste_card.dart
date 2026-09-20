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
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: NazzilColors.rose.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
        child: Column(
          children: [
            TextField(
              controller: _text,
              onChanged: widget.controller.setUrl,
              minLines: 2,
              maxLines: 4,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: s.pasteHint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    await widget.controller.paste(data?.text ?? '');
                  },
                  icon: const Icon(Icons.content_paste_rounded, size: 16, color: NazzilColors.rose),
                  label: Text(s.paste, style: const TextStyle(color: NazzilColors.rose)),
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
