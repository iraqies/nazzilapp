import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/nazzil_controller.dart';
import '../widgets/choice_row.dart';
import '../widgets/heading.dart';
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
