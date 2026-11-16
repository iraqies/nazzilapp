import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';
import '../widgets/choice_row.dart';
import '../widgets/heading.dart';
import '../widgets/tile.dart';
import '../widgets/title_text.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final NazzilController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final theme = Theme.of(context);
    final remote = controller.remote;
    // A group's name heads its own tile, as Finery titles the tile it sits in.
    Widget title(String label) => Semantics(header: true, child: Text(label, style: theme.textTheme.titleMedium));
    Widget group(String label, Widget child) => Tile(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title(label), const SizedBox(height: 12), child],
          ),
        );
    final wide = NazzilLayout.isWide(context);
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
      // A wide window keeps the column readable in its middle, and its scroll bar at the window's edge.
      padding: EdgeInsets.symmetric(horizontal: math.max(16.0, (constraints.maxWidth - 640) / 2))
          .copyWith(top: wide ? 28 : 4, bottom: 40),
      children: [
        Eyebrow(s.appName, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Heading(s.settings, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        group(
          s.language,
          ChoiceRow(
            value: controller.settings.language,
            options: [
              ('system', s.system),
              ('en', s.english),
              ('ar', s.arabic),
            ],
            onChanged: controller.setLanguage,
          ),
        ),
        const SizedBox(height: 16),
        group(
          s.theme,
          ChoiceRow(
            value: controller.settings.theme,
            options: [
              ('dark', s.themeDark),
              ('light', s.themeLight),
              ('system', s.system),
            ],
            onChanged: controller.setTheme,
          ),
        ),
        const SizedBox(height: 16),
        group(s.about, Text(s.aboutBody, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
        const SizedBox(height: 16),
        // The rows run to the tile's edges, so a tap lights the whole row.
        Tile(
          padding: const EdgeInsets.only(top: 20, bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: title(s.credits)),
              const SizedBox(height: 4),
              _credit(context, 'iraqies', 'github.com/iraqies', 'https://github.com/iraqies'),
              _credit(context, 'Telegram', 't.me/weirdistic', 'https://t.me/weirdistic'),
              _credit(context, 'stalk.gg', 'stalk.gg/x', 'https://stalk.gg/x', last: true),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text.rich(
          TextSpan(
            text: '${s.version} ',
            children: [
              TextSpan(
                text: controller.localVersion,
                style: TextStyle(color: NazzilTheme.link(theme.brightness), fontWeight: NazzilTheme.strong),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        if (remote != null && controller.updates.isNewer(remote.version, controller.localVersion)) ...[
          const SizedBox(height: 16),
          Text(
            '${s.updateAvailable}: ${remote.version}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton(
              onPressed: () => launchUrl(Uri.parse(remote.apkUrl), mode: LaunchMode.externalApplication),
              child: Text(s.updateNow),
            ),
          ),
        ],
      ],
      ),
    );
  }

  Widget _credit(BuildContext context, String title, String handle, String url, {bool last = false}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsetsDirectional.fromSTEB(20, 2, 16, 2),
          shape: const RoundedRectangleBorder(),
          // Names and addresses in Latin letters, set as Latin in the Arabic app too.
          title: TitleText(title, style: theme.textTheme.titleSmall),
          subtitle: TitleText(handle, style: theme.textTheme.bodySmall),
          trailing: Icon(Icons.open_in_new_rounded, size: 18, color: NazzilTheme.link(theme.brightness)),
          onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        ),
        // A hairline between rows, inset to the words, as a grouped list parts its cells.
        if (!last)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 20),
            child: Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          ),
      ],
    );
  }
}
