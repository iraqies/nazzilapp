import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';
import '../widgets/segmented.dart';
import '../widgets/tappable.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final NazzilController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final theme = Theme.of(context);
    final remote = controller.remote;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
      children: [
        Text(s.language, style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        SegmentedChoice(
          value: controller.settings.language,
          options: [
            ('system', s.system),
            ('en', s.english),
            ('ar', s.arabic),
          ],
          onChanged: controller.setLanguage,
        ),
        const SizedBox(height: 28),
        Text(s.theme, style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        SegmentedChoice(
          value: controller.settings.theme,
          options: [
            ('system', s.system),
            ('light', s.themeLight),
            ('dark', s.themeDark),
          ],
          onChanged: controller.setTheme,
        ),
        const SizedBox(height: 28),
        Text(s.colour, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final palette in NazzilPalette.all)
              _Swatch(
                palette: palette,
                label: s.paletteName(palette.id),
                selected: controller.settings.palette == palette.id,
                onTap: () => controller.setPalette(palette.id),
              ),
          ],
        ),
        const SizedBox(height: 32),
        Text(s.about, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(s.aboutBody, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 28),
        Text(s.credits, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _credit(context, 'iraqies', 'github.com/iraqies', 'https://github.com/iraqies'),
        _credit(context, 'Telegram', 't.me/weirdistic', 'https://t.me/weirdistic'),
        _credit(context, 'stalk.gg', 'stalk.gg/x', 'https://stalk.gg/x'),
        const SizedBox(height: 20),
        Text('${s.version} ${controller.localVersion}', style: theme.textTheme.bodySmall),
        if (remote != null && controller.updates.isNewer(remote.version, controller.localVersion)) ...[
          const SizedBox(height: 12),
          Text('${s.updateAvailable}: ${remote.version}', style: theme.textTheme.titleMedium),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => launchUrl(Uri.parse(remote.apkUrl), mode: LaunchMode.externalApplication),
              child: Text(s.updateNow),
            ),
          ),
        ],
      ],
    );
  }

  Widget _credit(BuildContext context, String title, String handle, String url) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ListTile(
        tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
        title: Text(title),
        subtitle: Text(handle),
        trailing: const Icon(Icons.open_in_new_rounded, size: 16),
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.palette, required this.label, required this.selected, required this.onTap});
  final NazzilPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tappable(
      onTap: onTap,
      selected: selected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 58),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? scheme.onSurface : scheme.outline,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: palette.fill),
                  child: selected
                      ? const Center(child: Icon(Icons.check_rounded, color: NazzilColors.ink, size: 22))
                      : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
