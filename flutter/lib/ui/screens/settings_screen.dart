import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';
import '../widgets/segmented.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final NazzilController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
      children: [
        Text(s.language, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SegmentedChoice(
          value: controller.settings.language,
          options: [
            ('system', s.languageSystem),
            ('en', s.english),
            ('ar', s.arabic),
          ],
          onChanged: controller.setLanguage,
        ),
        const SizedBox(height: 28),
        Text(s.theme, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SegmentedChoice(
          value: controller.settings.theme,
          options: [
            ('system', s.themeSystem),
            ('light', s.themeLight),
            ('dark', s.themeDark),
          ],
          onChanged: controller.setTheme,
        ),
        const SizedBox(height: 32),
        Text(s.about, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(s.aboutBody, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 28),
        Text(s.credits, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _credit(context, 'iraqies', 'github.com/iraqies', 'https://github.com/iraqies'),
        _credit(context, 'Telegram', 't.me/weirdistic', 'https://t.me/weirdistic'),
        _credit(context, 'stalk.gg', 'stalk.gg/x', 'https://stalk.gg/x'),
        const SizedBox(height: 20),
        Text('${s.version} ${controller.localVersion}', style: Theme.of(context).textTheme.bodySmall),
        if (controller.remote != null &&
            controller.updates.isNewer(controller.remote!.version, controller.localVersion)) ...[
          const SizedBox(height: 12),
          Text(
            '${s.updateAvailable}: ${controller.remote!.version}',
            style: const TextStyle(color: NazzilColors.rose, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse(controller.remote!.apkUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(s.updateNow),
          ),
        ],
      ],
    );
  }

  Widget _credit(BuildContext context, String title, String handle, String url) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
        title: Text(title),
        subtitle: Text(handle),
        trailing: const Icon(Icons.open_in_new_rounded, size: 16),
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ),
    );
  }
}
