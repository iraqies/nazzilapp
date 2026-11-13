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
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final items = controller.visibleLibrary;
    final platforms = controller.libraryPlatforms;
    return Padding(
      // The grid stops below the status bar, so no picture passes behind the clock.
      padding: EdgeInsets.only(top: wide ? 0 : MediaQuery.paddingOf(context).top),
      child: CustomScrollView(
        key: const PageStorageKey('library'),
        slivers: [
          if (!wide) SliverToBoxAdapter(child: TopBar(controller: controller, onSettings: onSettings)),
          // Finery's catalogue head: the count as an eyebrow over the heading, centred.
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, wide ? 20 : 4, 20, 0),
              child: Column(
                children: [
                  if (controller.library.isNotEmpty) ...[
                    Eyebrow(s.itemsN(items.length), textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                  ],
                  Heading(s.library, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          if (controller.library.isNotEmpty)
            SliverToBoxAdapter(
              child: FocusTraversalGroup(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                      if (platforms.length > 1 || controller.libraryPlatform != 'all') _AppMenu(controller: controller),
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              sliver: SliverLayoutBuilder(
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
            ),
        ],
      ),
    );
  }
}

/// A filter as a pill: filled with the text colour when picked, a white tile edged
/// by a hairline when not. The pill stands 36 high inside a tap target of 48.
class _Pill extends StatelessWidget {
  const _Pill({required this.onTap, required this.active, required this.child, this.selected});
  final VoidCallback onTap;
  final bool active;
  final Widget child;
  final bool? selected;

  static TextStyle style(BuildContext context, {required bool active}) {
    final theme = Theme.of(context);
    return theme.textTheme.labelLarge!.copyWith(
      fontSize: 15,
      color: active ? theme.colorScheme.surface : theme.colorScheme.onSurface,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tappable(
      onTap: onTap,
      selected: selected,
      radius: NazzilRadius.pill,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active ? scheme.onSurface : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(NazzilRadius.pill),
              border: Border.all(color: active ? scheme.onSurface : scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A kind filter.
class _KindTab extends StatelessWidget {
  const _KindTab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      onTap: onTap,
      active: active,
      selected: active,
      child: Text(label, style: _Pill.style(context, active: active)),
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
    // By name, not from the apps present: a filter can outlive the last item it matched.
    final picked = PlatformId.values.where((p) => p.name == controller.libraryPlatform).firstOrNull;
    final style = _Pill.style(context, active: picked != null);
    return _Pill(
      onTap: () => _open(context),
      active: picked != null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(picked == null ? s.filterAllApps : s.platformName(picked), style: style)),
          const SizedBox(width: 2),
          Icon(Icons.expand_more_rounded, size: 20, color: style.color),
        ],
      ),
    );
  }
}
