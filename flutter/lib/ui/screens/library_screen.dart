import 'package:flutter/material.dart';

import '../../models/media.dart';
import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';
import '../widgets/glow_backdrop.dart';
import '../widgets/library_tile.dart';
import '../widgets/segmented.dart';
import 'viewer_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.controller});
  final NazzilController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final items = controller.visibleLibrary;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.library, style: displayStyle(context, size: 40)),
                const SizedBox(height: 6),
                Text(
                  '${items.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                SegmentedChoice(
                  value: controller.libraryKind,
                  options: [
                    ('all', s.filterAll),
                    ('photos', s.filterPhotos),
                    ('videos', s.filterVideos),
                    ('audio', s.filterAudio),
                  ],
                  onChanged: controller.setLibraryKind,
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final option in [
                        ('all', s.filterAll),
                        ('youtube', s.youtube),
                        ('tiktok', s.tiktok),
                        ('instagram', s.instagram),
                        ('facebook', s.facebook),
                      ])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: FilterChip(
                            selected: controller.libraryPlatform == option.$1,
                            label: Text(option.$2),
                            onSelected: (_) => controller.setLibraryPlatform(option.$1),
                            showCheckmark: false,
                            selectedColor: NazzilColors.rose.withValues(alpha: 0.2),
                            side: BorderSide(
                              color: controller.libraryPlatform == option.$1
                                  ? NazzilColors.rose
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Mark(size: 72),
                  const SizedBox(height: 22),
                  Text(
                    s.emptyLibrary,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.emptyLibraryHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  return LibraryTile(
                    item: item,
                    s: s,
                    kept: controller.libraryStore.stillHave(item),
                    progress: item.id == controller.activeJobId ? controller.progress : null,
                    onOpen: () => _open(context, item),
                    onCancel: item.active ? () => controller.cancelJob(item) : null,
                    onPause: item.status == LibraryItem.statusDownloading
                        ? () => controller.pauseJob(item)
                        : null,
                    onResume: item.paused ? () => controller.resumeJob(item) : null,
                  );
                },
                childCount: items.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 18,
                childAspectRatio: 0.62,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _open(BuildContext context, LibraryItem item) async {
    final s = controller.s;
    if (item.pending || item.paused) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (item.done && controller.libraryStore.stillHave(item)) ...[
                  ListTile(
                    leading: const Icon(Icons.play_arrow_rounded),
                    title: Text(item.kind == MediaKind.photo ? s.view : s.play),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ViewerScreen(item: item),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: Text(s.openGallery),
                    onTap: () {
                      Navigator.pop(context);
                      controller.openInGallery(item);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.ios_share_rounded),
                    title: Text(s.share),
                    onTap: () {
                      Navigator.pop(context);
                      controller.shareItem(item);
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.link_rounded),
                  title: Text(s.original),
                  onTap: () {
                    Navigator.pop(context);
                    controller.openOriginal(item.sourceUrl);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  title: Text(s.delete, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  onTap: () {
                    Navigator.pop(context);
                    controller.remove(item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
