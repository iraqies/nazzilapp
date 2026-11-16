import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/platforms.dart';
import '../../state/nazzil_controller.dart';
import 'link_frame.dart';
import 'logo.dart';
import 'nazzil_button.dart';

/// The logo, what the app is downloading, and the way in and out of Settings.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.controller, required this.onSettings, this.settingsOpen = false});
  final NazzilController controller;
  final VoidCallback onSettings;
  final bool settingsOpen;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 8, 4),
          child: Row(
            children: [
              Expanded(child: _Mark(controller: controller)),
              const SizedBox(width: 4),
              _SettingsButton(controller: controller, onSettings: onSettings, settingsOpen: settingsOpen),
            ],
          ),
        ),
      ),
    );
  }
}

/// The toolbar of a wide window: the logo and what is going on, the link field
/// with the button for the next step, and the way in and out of Settings.
class WideBar extends StatelessWidget {
  const WideBar({super.key, required this.controller, required this.onSettings, this.settingsOpen = false});
  final NazzilController controller;
  final VoidCallback onSettings;
  final bool settingsOpen;

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    await controller.paste(data?.text ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final loading = controller.loading;
    final typed = controller.url.trim().isNotEmpty;
    // The link of the post on show is no next step; a link typed over it is.
    final fresh = typed && (controller.media == null || controller.url.trim() != controller.fetchedUrl);
    final keys = defaultTargetPlatform == TargetPlatform.macOS ? '⌘V' : 'Ctrl+V';
    final hint = Platforms.desktop ? s.promptKeys(keys) : s.framePrompt;
    final scheme = Theme.of(context).colorScheme;
    // In the tiles' colour, as the phone's tab bar is, so the grey field stands out from it in both themes.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: FocusTraversalGroup(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 8, 10),
          child: Row(
            children: [
              _Mark(controller: controller),
              const SizedBox(width: 24),
              Expanded(
                // Settings leaves the field out but keeps its room, so the bar holds its height.
                child: Visibility(
                  visible: !settingsOpen,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Row(
                        children: [
                          Expanded(child: LinkFrame(controller: controller, s: s, hint: hint)),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 150),
                            child: IntrinsicWidth(
                              child: NazzilButton(
                                label: loading ? s.fetching : (fresh ? s.fetch : s.paste),
                                icon: fresh ? null : Icons.content_paste_rounded,
                                busy: loading,
                                onPressed: fresh ? () => controller.fetch() : _paste,
                              ),
                            ),
                          ),
                          if (loading)
                            IconButton(
                              tooltip: s.cancel,
                              onPressed: controller.cancelFetch,
                              icon: const Icon(Icons.close_rounded),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              _SettingsButton(controller: controller, onSettings: onSettings, settingsOpen: settingsOpen),
            ],
          ),
        ),
      ),
    );
  }
}

/// The logo, and under it what is going on: downloading or converting, how many
/// wait behind it, or that something is paused. With nothing going on, nothing.
class _Mark extends StatelessWidget {
  const _Mark({required this.controller});
  final NazzilController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final theme = Theme.of(context);
    final doing = controller.converting ? s.converting : s.downloading;
    final status = controller.downloading
        ? (controller.queuedCount > 0 ? '$doing · ${s.waitingN(controller.queuedCount)}' : doing)
        : (controller.library.any((e) => e.paused) ? s.paused : '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        NazzilLogo(height: 34, name: s.appName),
        Semantics(
          liveRegion: true,
          child: status.isEmpty ? const SizedBox.shrink() : Text(status, style: theme.textTheme.labelMedium),
        ),
      ],
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.controller, required this.onSettings, required this.settingsOpen});
  final NazzilController controller;
  final VoidCallback onSettings;
  final bool settingsOpen;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    return IconButton(
      tooltip: settingsOpen ? s.back : s.settings,
      onPressed: onSettings,
      icon: Icon(settingsOpen ? Icons.arrow_back_rounded : Icons.settings_outlined),
    );
  }
}
