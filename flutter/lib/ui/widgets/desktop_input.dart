import 'dart:convert';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/link_parser.dart';
import '../../data/platforms.dart';
import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';

/// Desktop link input: drop a link (or a .url / .webloc shortcut) anywhere
/// on the window, or press Ctrl+V / Cmd+V.
class DesktopInput extends StatefulWidget {
  const DesktopInput({super.key, required this.controller, required this.child, this.onEscape});
  final NazzilController controller;
  final Widget child;

  /// Called for the Esc key, unless a dialog or a menu over the window takes it first.
  final VoidCallback? onEscape;

  @override
  State<DesktopInput> createState() => _DesktopInputState();
}

class _DesktopInputState extends State<DesktopInput> {
  bool _hovering = false;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isNotEmpty) await widget.controller.ingest(text);
  }

  Future<void> _drop(DropDoneDetails details) async {
    setState(() => _hovering = false);
    final texts = <String>[
      if (details.rawText != null) details.rawText!,
      for (final item in details.files)
        if (item.path.startsWith('http')) item.path,
    ];
    for (final item in details.files) {
      final file = File(item.path);
      try {
        if (file.existsSync() && file.lengthSync() < 64 * 1024) {
          texts.add(utf8.decode(await file.readAsBytes(), allowMalformed: true));
        }
      } catch (_) {}
    }
    for (final text in texts) {
      final link = LinkParser.extract(text);
      if (link.isNotEmpty) {
        await widget.controller.ingest(link);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platforms.desktop) return widget.child;
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final scheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyV, control: !mac, meta: mac): _paste,
        const SingleActivator(LogicalKeyboardKey.escape): ?widget.onEscape,
      },
      child: Focus(
        autofocus: true,
        // It holds focus so the shortcut works from the start; the Tab key has no ring to show here.
        skipTraversal: true,
        child: DropTarget(
          onDragEntered: (_) => setState(() => _hovering = true),
          onDragExited: (_) => setState(() => _hovering = false),
          onDragDone: _drop,
          child: Stack(
            children: [
              widget.child,
              if (_hovering)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(NazzilRadius.sheet),
                        border: Border.all(color: scheme.onSurface, width: 2),
                      ),
                      child: Center(
                        child: Icon(Icons.link_rounded, size: 72, color: scheme.onSurface),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
