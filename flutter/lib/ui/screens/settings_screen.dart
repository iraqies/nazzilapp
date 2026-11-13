import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';
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
    // A group's name, quiet and small, above what it holds, as a settings page sets them.
    Widget section(String label) => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 24, 4, 8),
          child: Semantics(header: true, child: Text(label, style: theme.textTheme.labelMedium)),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        Heading(s.settings),
        const SizedBox(height: 8),
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
        section(s.about),
        _Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(s.aboutBody, style: theme.textTheme.bodyMedium),
          ),
        ),
        section(s.credits),
        _Card(
          child: Column(
            children: [
              _credit(context, 'iraqies', 'github.com/iraqies', 'https://github.com/iraqies'),
              _credit(context, 'Telegram', 't.me/weirdistic', 'https://t.me/weirdistic'),
              _credit(context, 'stalk.gg', 'stalk.gg/x', 'https://stalk.gg/x', last: true),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: Text('${s.version} ${controller.localVersion}', style: theme.textTheme.bodySmall),
        ),
        if (remote != null && controller.updates.isNewer(remote.version, controller.localVersion)) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Text('${s.updateAvailable}: ${remote.version}', style: theme.textTheme.titleSmall),
          ),
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

  Widget _credit(BuildContext context, String title, String handle, String url, {bool last = false}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
          // Names and addresses in Latin letters, set as Latin in the Arabic app too.
          title: TitleText(title, style: theme.textTheme.titleSmall),
          subtitle: TitleText(handle, style: theme.textTheme.bodySmall),
          trailing: Icon(Icons.open_in_new_rounded, size: 18, color: scheme.onSurfaceVariant),
          onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        ),
        // A hairline between rows, inset to the words, as a grouped list parts its cells.
        if (!last)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16),
            child: Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          ),
      ],
    );
  }
}

/// A grouped card: a rounded panel of the sheet colour that lifts a little off the page,
/// the way iOS gathers a settings group.
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NazzilRadius.card),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
