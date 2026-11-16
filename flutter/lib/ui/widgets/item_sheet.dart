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

/// One thing to do with a library item. A [danger] one is drawn in the warning red.
typedef ItemAction = ({IconData icon, String label, VoidCallback run, bool danger});

/// What can be done with [item] as it stands, in the order the sheet lists it.
/// An action that goes on elsewhere calls [close] first, then goes on in [above].
List<ItemAction> itemActions(
  BuildContext above,
  NazzilController controller,
  LibraryItem item, {
  required VoidCallback close,
}) {
  final s = controller.s;
  final running = item.id == controller.activeJobId;
  final arriving = item.status == LibraryItem.statusDownloading && running && !controller.converting;
  final stopped = item.status == LibraryItem.statusFailed || item.status == LibraryItem.statusCancelled;
  final photo = item.kind == MediaKind.photo;
  ItemAction action(IconData icon, String label, VoidCallback run, {bool danger = false}) =>
      (icon: icon, label: label, run: run, danger: danger);
  return [
    if (item.done && controller.libraryStore.stillHave(item)) ...[
      action(photo ? Icons.photo_outlined : Icons.play_arrow_rounded, photo ? s.view : s.play, () {
        close();
        Navigator.push(
          above,
          NazzilMotion.route<void>(above, (_) => ViewerScreen(controller: controller, item: item)),
        );
      }),
      // A phone opens its gallery here; a computer hands the file to another app.
      action(Platforms.desktop ? Icons.open_in_new_rounded : Icons.photo_library_outlined, s.openGallery, () async {
        final messenger = ScaffoldMessenger.of(above);
        final motion = NazzilMotion.style(above);
        close();
        if (await controller.openInGallery(item)) return;
        messenger.showSnackBar(SnackBar(content: Text(s.cantOpen)), snackBarAnimationStyle: motion);
      }),
      if (Platforms.fileShare)
        action(Icons.ios_share_rounded, s.share, () {
          close();
          controller.shareItem(item);
        }),
    ] else if (item.active) ...[
      if (arriving) action(Icons.pause_rounded, s.pause, () => controller.pauseJob(item)),
      if (item.paused) action(Icons.play_arrow_rounded, s.resume, () => controller.resumeJob(item)),
      action(Icons.close_rounded, s.cancel, () => controller.cancelJob(item)),
    ] else
      action(Icons.refresh_rounded, stopped ? s.retry : s.downloadAgain, () {
        close();
        controller.retryJob(item);
      }),
    action(Icons.link_rounded, s.original, () {
      close();
      controller.openOriginal(item.sourceUrl);
    }),
    if (!item.active)
      action(Icons.delete_outline, s.delete, danger: true, () {
        close();
        deleteItem(above, controller, item);
      }),
  ];
}

/// Opens the sheet of a library item: its title, where it stands, and every
/// action for it. A wide window shows it as a dialog in its middle instead of
/// a sheet from its foot. [context] is the page the sheet is opened from.
Future<void> showItemSheet(BuildContext context, NazzilController controller, LibraryItem item) {
  // The actions go on after the sheet has closed: a viewer to open, a question to ask, a
  // line to show. The page cannot carry them. A share from another app, or a tap on a
  // notification, changes the tab under an open sheet, and the page is gone by then.
  // What holds the pages is still there.
  final above = Navigator.of(context).context;
  final wide = NazzilLayout.isWide(context);
  // The item is looked up on every change, so the sheet follows a download as it moves on.
  Widget follow(BuildContext sheet) => ListenableBuilder(
        listenable: controller,
        builder: (_, _) {
          final now = controller.library.where((e) => e.id == item.id).firstOrNull;
          if (now == null) return const SizedBox(width: double.infinity, height: 24);
          return _ItemSheet(above: above, sheet: sheet, controller: controller, item: now, dialog: wide);
        },
      );
  if (wide) {
    return showDialog<void>(
      context: context,
      animationStyle: NazzilMotion.style(context),
      builder: (dialog) => Dialog(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: follow(dialog)),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: NazzilMotion.style(context),
    builder: follow,
  );
}

/// Opens the actions of [item] as a menu at [position], where a pointer's
/// secondary button went down on its card.
Future<void> showItemMenu(BuildContext context, NazzilController controller, LibraryItem item, Offset position) async {
  final above = Navigator.of(context).context;
  final scheme = Theme.of(context).colorScheme;
  final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  // The menu closes itself on a pick, so there is nothing more for an action to close.
  final actions = itemActions(above, controller, item, close: () {});
  final picked = await showMenu<VoidCallback>(
    context: context,
    popUpAnimationStyle: NazzilMotion.style(context),
    position: RelativeRect.fromRect(overlay.globalToLocal(position) & Size.zero, Offset.zero & overlay.size),
    items: [
      for (final action in actions)
        PopupMenuItem<VoidCallback>(
          value: action.run,
          height: 48,
          child: Row(
            children: [
              Icon(action.icon, size: 20, color: action.danger ? scheme.error : scheme.onSurface),
              const SizedBox(width: 12),
              Flexible(
                child: Text(action.label, style: action.danger ? TextStyle(color: scheme.error) : null),
              ),
            ],
          ),
        ),
    ],
  );
  picked?.call();
}

class _ItemSheet extends StatelessWidget {
  const _ItemSheet({
    required this.above,
    required this.sheet,
    required this.controller,
    required this.item,
    required this.dialog,
  });

  /// Where the actions go on once the sheet has closed. It outlives the page under the sheet.
  final BuildContext above;
  final BuildContext sheet;
  final NazzilController controller;
  final LibraryItem item;

  /// Shown as a dialog, which has no drag handle over it and no edge of the screen under it.
  final bool dialog;

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

    final body = SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(4, dialog ? 24 : 0, 4, 12),
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
            for (final action in itemActions(above, controller, item, close: _close))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Icon(action.icon, color: action.danger ? scheme.error : null),
                title: Text(action.label, style: action.danger ? TextStyle(color: scheme.error) : null),
                onTap: action.run,
              ),
          ],
        ),
      );
    return dialog ? body : SafeArea(child: body);
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
