import 'package:flutter/material.dart';

import '../../data/platforms.dart';
import '../../models/media.dart';
import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';
import '../screens/viewer_screen.dart';
import 'arriving.dart';
import 'cover.dart';
import 'library_tile.dart';
import 'title_text.dart';

/// Opens the sheet of a library item: its title, where it stands, and every
/// action for it. [context] is the page under the sheet, which the actions
/// go on using after the sheet has closed.
Future<void> showItemSheet(BuildContext context, NazzilController controller, LibraryItem item) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: NazzilMotion.style(context),
    builder: (sheet) => ListenableBuilder(
      listenable: controller,
      // The item is looked up on every change, so the sheet follows a download as it moves on.
      builder: (_, _) {
        final now = controller.library.where((e) => e.id == item.id).firstOrNull;
        if (now == null) return const SizedBox(width: double.infinity, height: 24);
        return _ItemSheet(page: context, sheet: sheet, controller: controller, item: now);
      },
    ),
  );
}

class _ItemSheet extends StatelessWidget {
  const _ItemSheet({required this.page, required this.sheet, required this.controller, required this.item});
  final BuildContext page;
  final BuildContext sheet;
  final NazzilController controller;
  final LibraryItem item;

  void _close() => Navigator.pop(sheet);

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kept = controller.libraryStore.stillHave(item);
    final running = item.id == controller.activeJobId;
    final converting = running && controller.converting;
    final downloading = item.status == LibraryItem.statusDownloading;
    final failed = item.status == LibraryItem.statusFailed;
    final stopped = failed || item.status == LibraryItem.statusCancelled;
    final saved = item.done && kept;
    final arriving = downloading && running && !converting;
    final tag = itemTag(item, s, kept: kept, progress: running ? controller.progress : null, converting: converting);
    // A tile has room for the number alone; here it gets its word.
    final state = arriving ? '${s.downloading} ${tag.text}' : tag.text;
    final duration = item.duration;
    final facts = [
      s.platformName(item.platform),
      switch (item.kind) {
        MediaKind.photo => item.photoCount > 1 ? s.photosN(item.photoCount) : s.photo,
        MediaKind.audio => s.audio,
        MediaKind.video => duration != null && duration > 0 ? s.clock(duration) : s.video,
      },
      // Two saves of one video differ in nothing else.
      if (item.kind == MediaKind.video)
        switch (item.quality) {
          'HD' => s.hd,
          'SD' => s.sd,
          'Video' => '',
          final other => other,
        },
    ].where((fact) => fact.isNotEmpty).join(' · ');

    Widget row(IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Icon(icon, color: color),
          title: Text(label, style: color == null ? null : TextStyle(color: color)),
          onTap: onTap,
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 60,
                    height: 80,
                    child: ExcludeSemantics(
                      child: ColoredBox(
                        color: scheme.surfaceContainerHigh,
                        child: ArrivingPicture(
                          progress: arriving ? controller.progress : null,
                          unsaved: !arriving && !saved && !converting,
                          ghost: Cover(item: item, extent: 80, bare: true),
                          child: Cover(item: item, extent: 80),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: TitleText(item.title, maxLines: 3, style: theme.textTheme.titleMedium),
                        ),
                        if (facts.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(facts, style: theme.textTheme.bodySmall),
                        ],
                        if (!saved) ...[
                          const SizedBox(height: 6),
                          // The icon marks a failure where words alone would rest on the red.
                          Semantics(
                            liveRegion: true,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(top: 1, end: 6),
                                  child: Icon(tag.icon, size: 18, color: failed ? scheme.error : scheme.onSurface),
                                ),
                                Expanded(
                                  child: Text(
                                    state,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: failed ? scheme.error : scheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (saved) ...[
              row(
                item.kind == MediaKind.photo ? Icons.photo_outlined : Icons.play_arrow_rounded,
                item.kind == MediaKind.photo ? s.view : s.play,
                () {
                  _close();
                  Navigator.push(
                    page,
                    NazzilMotion.route<void>(page, (_) => ViewerScreen(controller: controller, item: item)),
                  );
                },
              ),
              row(
                // A phone opens its gallery here; a computer hands the file to another app.
                Platforms.desktop ? Icons.open_in_new_rounded : Icons.photo_library_outlined,
                s.openGallery,
                () async {
                  final messenger = ScaffoldMessenger.of(page);
                  final motion = NazzilMotion.style(page);
                  _close();
                  if (await controller.openInGallery(item)) return;
                  messenger.showSnackBar(SnackBar(content: Text(s.cantOpen)), snackBarAnimationStyle: motion);
                },
              ),
              if (Platforms.fileShare)
                row(Icons.ios_share_rounded, s.share, () {
                  _close();
                  controller.shareItem(item);
                }),
            ] else if (item.active) ...[
              if (arriving) row(Icons.pause_rounded, s.pause, () => controller.pauseJob(item)),
              if (item.paused) row(Icons.play_arrow_rounded, s.resume, () => controller.resumeJob(item)),
              row(Icons.close_rounded, s.cancel, () => controller.cancelJob(item)),
            ] else
              row(Icons.refresh_rounded, stopped ? s.retry : s.downloadAgain, () {
                _close();
                controller.retryJob(item);
              }),
            row(Icons.link_rounded, s.original, () {
              _close();
              controller.openOriginal(item.sourceUrl);
            }),
            if (!item.active)
              row(Icons.delete_outline, s.delete, color: scheme.error, () {
                _close();
                deleteItem(page, controller, item);
              }),
          ],
        ),
      ),
    );
  }
}

/// Removes [item] from the library. It asks first only when a saved file would go with the entry.
Future<void> deleteItem(BuildContext context, NazzilController controller, LibraryItem item) async {
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
