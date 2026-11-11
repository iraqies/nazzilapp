import 'package:flutter/material.dart';

import '../../models/media.dart';
import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';
import '../widgets/heading.dart';
import '../widgets/item_sheet.dart';
import '../widgets/library_tile.dart';
import '../widgets/state_message.dart';
import '../widgets/tappable.dart';
import '../widgets/top_bar.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.controller, required this.onSettings, this.wide = false});
  final NazzilController controller;
  final VoidCallback onSettings;

  /// Beside the link pane on a wide window: the shell draws the header, and
  /// an empty library has no "Add a link" to offer, since the link pane is in view.
  final bool wide;

  static const _maxTile = 220.0;
  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final theme = Theme.of(context);
    final items = controller.visibleLibrary;
    final platforms = controller.libraryPlatforms;
    final arabic = s.isAr;
    return Padding(
      // The wall stops below the status bar, so no picture passes behind the clock.
      padding: EdgeInsets.only(top: wide ? 0 : MediaQuery.paddingOf(context).top),
      child: CustomScrollView(
        key: const PageStorageKey('library'),
        slivers: [
          if (!wide) SliverToBoxAdapter(child: TopBar(controller: controller, onSettings: onSettings)),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, wide ? 20 : 8, 20, 0),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 12,
                children: [
                  Heading(s.library),
                  if (controller.library.isNotEmpty)
                    Padding(
                      // Sets the count on the baseline of the heading beside it.
                      padding: EdgeInsets.only(bottom: arabic ? 9 : 5),
                      child: Text(s.itemsN(items.length), style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
            ),
          ),
          if (controller.library.isNotEmpty)
            SliverToBoxAdapter(
              child: FocusTraversalGroup(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(11, 4, 10, 4),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(2),
                        child: Wrap(
                          children: [
                            for (final kind in [
                              ('all', s.filterAll),
                              ('photos', s.filterPhotos),
                              ('videos', s.filterVideos),
                              ('audio', s.filterAudio),
                            ])
                              _KindTab(
                                label: kind.$2,
                                active: controller.libraryKind == kind.$1,
                                onTap: () => controller.setLibraryKind(kind.$1),
                              ),
                          ],
                        ),
                      ),
                      if (platforms.length > 1 || controller.libraryPlatform != 'all')
                        Padding(
                          padding: const EdgeInsets.all(2),
                          child: _AppMenu(controller: controller),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: controller.library.isEmpty
                  ? StateMessage(
                      title: s.emptyLibrary,
                      body: s.emptyLibraryHint,
                      actions: [if (!wide) (s.addLink, () => controller.goTab(0))],
                    )
                  : StateMessage(
                      title: s.emptyFilter,
                      actions: [(s.showAll, controller.clearLibraryFilters)],
                    ),
            )
          else
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns = ((width + _gap) / (_maxTile + _gap)).ceil().clamp(2, 12);
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      final running = item.id == controller.activeJobId;
                      return LibraryTile(
                        item: item,
                        s: s,
                        kept: controller.libraryStore.stillHave(item),
                        progress: running ? controller.progress : null,
                        converting: running && controller.converting,
                        onOpen: () => showItemSheet(context, controller, item),
                      );
                    },
                    childCount: items.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: _gap,
                    mainAxisSpacing: _gap,
                    childAspectRatio: LibraryTile.ratio,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// A kind filter: plain words, underlined when picked.
class _KindTab extends StatelessWidget {
  const _KindTab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tappable(
      onTap: onTap,
      selected: active,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: active ? scheme.onSurface : Colors.transparent, width: 2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: active ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app filter: one button that names the pick and opens the list.
class _AppMenu extends StatelessWidget {
  const _AppMenu({required this.controller});
  final NazzilController controller;

  Future<void> _open(BuildContext context) async {
    final s = controller.s;
    final theme = Theme.of(context);
    final button = context.findRenderObject()! as RenderBox;
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final picked = await showMenu<String>(
      context: context,
      popUpAnimationStyle: NazzilMotion.style(context),
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(button.size.bottomLeft(Offset.zero), ancestor: overlay),
          button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
        ),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final option in [
          ('all', s.filterAllApps),
          for (final platform in controller.libraryPlatforms) (platform.name, s.platformName(platform)),
        ])
          PopupMenuItem<String>(
            value: option.$1,
            height: 48,
            child: Semantics(
              selected: controller.libraryPlatform == option.$1,
              child: Row(
                children: [
                  Expanded(child: Text(option.$2)),
                  const SizedBox(width: 16),
                  // The tick takes its room on every row, so the names line up.
                  SizedBox.square(
                    dimension: 20,
                    child: controller.libraryPlatform == option.$1
                        ? Icon(Icons.check_rounded, size: 20, color: theme.colorScheme.onSurface)
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    if (picked != null) controller.setLibraryPlatform(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final theme = Theme.of(context);
    // By name, not from the apps present: a filter can outlive the last item it matched.
    final picked = PlatformId.values.where((p) => p.name == controller.libraryPlatform).firstOrNull;
    return Tappable(
      onTap: () => _open(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  picked == null ? s.filterAllApps : s.platformName(picked),
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.expand_more_rounded, size: 22, color: theme.colorScheme.onSurface),
            ],
          ),
        ),
      ),
    );
  }
}
