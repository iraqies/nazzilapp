import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';
import '../widgets/choice_row.dart';
import '../widgets/heading.dart';
import '../widgets/tappable.dart';
import '../widgets/title_text.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final NazzilController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final theme = Theme.of(context);
    final remote = controller.remote;
    Widget section(String label) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(header: true, child: Text(label, style: theme.textTheme.titleMedium)),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Heading(s.settings),
        const SizedBox(height: 24),
        section(s.language),
        ChoiceRow(
          value: controller.settings.language,
          options: [
            ('system', s.system),
            ('en', s.english),
            ('ar', s.arabic),
          ],
          onChanged: controller.setLanguage,
        ),
        const SizedBox(height: 28),
        section(s.theme),
        ChoiceRow(
          value: controller.settings.theme,
          options: [
            ('dark', s.themeDark),
            ('light', s.themeLight),
            ('system', s.system),
          ],
          onChanged: controller.setTheme,
        ),
        const SizedBox(height: 28),
        section(s.colour),
        // The four stand in one row on a 360 wide phone, and fold onto a second where
        // the screen is narrower or the text is set larger.
        Wrap(
          spacing: 4,
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
        section(s.about),
        Text(s.aboutBody, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 28),
        section(s.credits),
        _credit(context, 'iraqies', 'github.com/iraqies', 'https://github.com/iraqies'),
        const Divider(),
        _credit(context, 'Telegram', 't.me/weirdistic', 'https://t.me/weirdistic'),
        const Divider(),
        _credit(context, 'stalk.gg', 'stalk.gg/x', 'https://stalk.gg/x'),
        const SizedBox(height: 20),
        Text('${s.version} ${controller.localVersion}', style: theme.textTheme.bodySmall),
        if (remote != null && controller.updates.isNewer(remote.version, controller.localVersion)) ...[
          const SizedBox(height: 16),
          Text('${s.updateAvailable}: ${remote.version}', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(
              onPressed: () => launchUrl(Uri.parse(remote.apkUrl), mode: LaunchMode.externalApplication),
              child: Text(s.updateNow),
            ),
          ),
        ],
      ],
    );
  }

  Widget _credit(BuildContext context, String title, String handle, String url) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      // Names and addresses in Latin letters, set as Latin in the Arabic app too.
      title: TitleText(title, style: theme.textTheme.titleSmall),
      subtitle: TitleText(handle, style: theme.textTheme.bodySmall),
      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
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
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The picked one gets a ring and a tick, so the pick does not rest on colour alone.
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(NazzilRadius.control + 4),
                  border: Border.all(color: selected ? scheme.onSurface : Colors.transparent, width: 2),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.fill,
                    borderRadius: BorderRadius.circular(NazzilRadius.control),
                  ),
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
