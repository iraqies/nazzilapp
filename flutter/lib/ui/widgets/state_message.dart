import 'package:flutter/material.dart';

/// An empty or failed screen: what happened, then what to do about it.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.title,
    this.body,
    this.actions = const [],
    this.onPhoto = false,
  });

  final String title;
  final String? body;
  final List<(String, VoidCallback)> actions;

  /// Shown over the black photo viewer rather than the page surface.
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(color: onPhoto ? Colors.white : null),
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onPhoto ? Colors.white : scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                children: [
                  for (final action in actions)
                    TextButton(
                      onPressed: action.$2,
                      style: onPhoto ? TextButton.styleFrom(foregroundColor: Colors.white) : null,
                      child: Text(action.$1),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
