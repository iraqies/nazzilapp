import 'package:flutter/material.dart';

import '../../models/media.dart';
import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';
import '../widgets/heading.dart';
import '../widgets/library_tile.dart';
import '../widgets/nazzil_chip.dart';
import '../widgets/segmented.dart';
import '../widgets/state_message.dart';
import '../widgets/title_text.dart';
import 'viewer_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.controller, this.showAddLink = true});
  final NazzilController controller;

  /// Off when the link box sits beside the library, as on a wide window.
  final bool showAddLink;

  static const _maxTile = 220.0;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final theme = Theme.of(context);
    final items = controller.visibleLibrary;
    final platforms = controller.libraryPlatforms;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Heading(s.library),
                if (controller.library.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(s.itemsN(items.length), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: SegmentedChoice(
                      value: controller.libraryKind,
                      options: [
                        ('all', s.filterAll),
                        ('photos', s.filterPhotos),
                        ('videos', s.filterVideos),
                        ('audio', s.filterAudio),
                      ],
                      onChanged: controller.setLibraryKind,
                    ),
                  ),
                ],
                if (platforms.length > 1 || controller.libraryPlatform != 'all') ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      children: [
                        for (final option in [
                          ('all', s.filterAllApps),
                          for (final platform in platforms) (platform.name, s.platformName(platform)),
                        ])
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: NazzilChip(
                              label: option.$2,
                              selected: controller.libraryPlatform == option.$1,
                              onTap: () => controller.setLibraryPlatform(option.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
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
                    actions: [if (showAddLink) (s.addLink, () => controller.goTab(0))],
                  )
                : StateMessage(
                    title: s.emptyFilter,
                    actions: [(s.showAll, controller.clearLibraryFilters)],
                  ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns = ((width + _gap) / (_maxTile + _gap)).ceil().clamp(2, 12);
                final tile = (width - _gap * (columns - 1)) / columns;
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      final kept = controller.libraryStore.stillHave(item);
                      final stopped = item.status == LibraryItem.statusFailed ||
                          item.status == LibraryItem.statusCancelled;
                      return LibraryTile(
                        item: item,
                        s: s,
                        kept: kept,
                        progress: item.id == controller.activeJobId ? controller.progress : null,
                        onOpen: () => _open(context, item),
                        onCancel: item.active ? () => controller.cancelJob(item) : null,
                        onPause: item.status == LibraryItem.statusDownloading
                            ? () => controller.pauseJob(item)
                            : null,
                        onResume: item.paused ? () => controller.resumeJob(item) : null,
                        onRetry: stopped || (item.done && !kept) ? () => controller.retryJob(item) : null,
                      );
                    },
                    childCount: items.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: _gap,
                    mainAxisSpacing: 18,
                    mainAxisExtent: LibraryTile.heightFor(context, tile),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _open(BuildContext context, LibraryItem item) async {
    final s = controller.s;
    if (item.pending || item.paused) return;
    final kept = controller.libraryStore.stillHave(item);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      sheetAnimationStyle: NazzilMotion.style(context),
      builder: (sheet) {
        final error = Theme.of(sheet).colorScheme.error;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TitleText(item.title, style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (item.done && kept) ...[
                  ListTile(
                    leading: Icon(item.kind == MediaKind.photo ? Icons.photo_outlined : Icons.play_arrow_rounded),
                    title: Text(item.kind == MediaKind.photo ? s.view : s.play),
                    onTap: () {
                      Navigator.pop(sheet);
                      Navigator.push(
                        context,
                        NazzilMotion.route<void>(
                          context,
                          (_) => ViewerScreen(controller: controller, item: item),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: Text(s.openGallery),
                    onTap: () {
                      Navigator.pop(sheet);
                      controller.openInGallery(item);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.ios_share_rounded),
                    title: Text(s.share),
                    onTap: () {
                      Navigator.pop(sheet);
                      controller.shareItem(item);
                    },
                  ),
                ] else
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded),
                    title: Text(item.done ? s.downloadAgain : s.retry),
                    onTap: () {
                      Navigator.pop(sheet);
                      controller.retryJob(item);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.link_rounded),
                  title: Text(s.original),
                  onTap: () {
                    Navigator.pop(sheet);
                    controller.openOriginal(item.sourceUrl);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: error),
                  title: Text(s.delete, style: TextStyle(color: error)),
                  onTap: () {
                    Navigator.pop(sheet);
                    _delete(context, item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Asks first only when a saved file would go with the entry.
  Future<void> _delete(BuildContext context, LibraryItem item) async {
    final s = controller.s;
    if (!controller.libraryStore.stillHave(item)) {
      await controller.remove(item);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: NazzilMotion.style(context),
      builder: (dialog) => AlertDialog(
        title: Text(s.deleteTitle),
        content: Text(s.deleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            style: TextButton.styleFrom(foregroundColor: Theme.of(dialog).colorScheme.onSurface),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(dialog).colorScheme.error),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.remove(item);
  }
}
