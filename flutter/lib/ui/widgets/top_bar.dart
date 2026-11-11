import 'package:flutter/material.dart';

import '../../state/nazzil_controller.dart';
import 'logo.dart';

/// The logo, what the app is downloading, and the way in and out of Settings.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.controller, required this.onSettings, this.settingsOpen = false});
  final NazzilController controller;
  final VoidCallback onSettings;
  final bool settingsOpen;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final theme = Theme.of(context);
    final doing = controller.converting ? s.converting : s.downloading;
    final status = controller.downloading
        ? (controller.queuedCount > 0 ? '$doing · ${s.waitingN(controller.queuedCount)}' : doing)
        : (controller.library.any((e) => e.paused) ? s.paused : '');
    return FocusTraversalGroup(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NazzilLogo(height: 34, name: s.appName),
                    Semantics(
                      liveRegion: true,
                      child: status.isEmpty
                          ? const SizedBox.shrink()
                          : Text(status, style: theme.textTheme.labelMedium),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: settingsOpen ? s.back : s.settings,
                onPressed: onSettings,
                icon: Icon(settingsOpen ? Icons.arrow_back_rounded : Icons.settings_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
