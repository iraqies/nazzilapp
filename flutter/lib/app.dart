import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/host.dart';
import 'data/platforms.dart';
import 'models/media.dart';
import 'state/nazzil_controller.dart';
import 'theme/nazzil_theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/viewer_screen.dart';
import 'ui/widgets/cover.dart';
import 'ui/widgets/desktop_input.dart';
import 'ui/widgets/done_sheet.dart';
import 'ui/widgets/tappable.dart';
import 'ui/widgets/top_bar.dart';

class NazzilApp extends StatelessWidget {
  const NazzilApp({super.key, required this.controller});
  final NazzilController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.s;
        return MaterialApp(
          title: s.appName,
          debugShowCheckedModeBanner: false,
          theme: NazzilTheme.light(arabic: s.isAr),
          darkTheme: NazzilTheme.dark(arabic: s.isAr),
          themeMode: controller.themeMode,
          locale: controller.locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: s.rtl ? TextDirection.rtl : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: NazzilShell(controller: controller),
        );
      },
    );
  }
}

class NazzilShell extends StatefulWidget {
  const NazzilShell({super.key, required this.controller});
  final NazzilController controller;

  @override
  State<NazzilShell> createState() => _NazzilShellState();
}

class _NazzilShellState extends State<NazzilShell> with WidgetsBindingObserver {
  /// From this width up the link pane and the library sit side by side.
  static const _wide = 960.0;

  bool _settings = false;
  String? _presentedDoneId;
  String? _presentedDupId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onController);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onController);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.offerClipboard();
    }
  }

  void _toggleSettings() => setState(() => _settings = !_settings);

  void _view(LibraryItem item) {
    Navigator.push(
      context,
      NazzilMotion.route<void>(context, (_) => ViewerScreen(controller: widget.controller, item: item)),
    );
  }

  void _onController() {
    if (widget.controller.doneItem == null) _presentedDoneId = null;
    if (widget.controller.duplicate == null) _presentedDupId = null;

    final done = widget.controller.doneItem;
    if (done != null && done.id != _presentedDoneId && mounted) {
      _presentedDoneId = done.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final s = widget.controller.s;
        showDialog<void>(
          context: context,
          animationStyle: NazzilMotion.style(context),
          builder: (dialog) => DoneSheet(
            s: s,
            photos: done.kind == MediaKind.photo,
            onePhoto: done.kind == MediaKind.photo && !done.isAlbum,
            cover: Cover(item: done, extent: 380),
            ghost: Cover(item: done, extent: 380, bare: true),
            onView: () {
              Navigator.pop(dialog);
              widget.controller.dismissSheets();
              _view(done);
            },
            onShare: Platforms.fileShare
                ? () {
                    Navigator.pop(dialog);
                    widget.controller.shareItem(done);
                    widget.controller.dismissSheets();
                  }
                : null,
            onClose: () {
              Navigator.pop(dialog);
              widget.controller.dismissSheets();
            },
          ),
        ).whenComplete(widget.controller.dismissSheets);
      });
      return;
    }

    final dup = widget.controller.duplicate;
    if (dup == null || dup.id == _presentedDupId || !mounted) return;
    _presentedDupId = dup.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = widget.controller.s;
      showDialog<void>(
        context: context,
        animationStyle: NazzilMotion.style(context),
        builder: (dialog) => AlertDialog(
          title: Text(s.alreadyHave),
          content: Text(s.alreadyHaveBody),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialog);
                widget.controller.dismissSheets();
              },
              child: Text(s.close),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialog);
                widget.controller.dismissSheets();
                _view(dup);
              },
              child: Text(dup.kind == MediaKind.photo ? s.view : s.play),
            ),
          ],
        ),
      ).whenComplete(widget.controller.dismissSheets);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final wide = media.size.width - media.padding.horizontal >= _wide;
    // The Tab key walks one group to its end before the next: header, page, tabs,
    // and on a wide window one pane before the other. A scrolled page cannot cut in.
    final Widget page;
    if (wide || _settings) {
      // One header for the whole window. On a phone each tab draws its own,
      // because the poster of a fetched post takes the header's place.
      page = SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _settings ? 640 : 1280),
            child: Column(
              children: [
                TopBar(controller: controller, onSettings: _toggleSettings, settingsOpen: _settings),
                if (wide && !_settings) const Divider(),
                Expanded(
                  child: FocusTraversalGroup(
                    child: _settings
                        ? SettingsScreen(controller: controller)
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 460,
                                child: FocusTraversalGroup(
                                  child: HomeScreen(controller: controller, onSettings: _toggleSettings, wide: true),
                                ),
                              ),
                              const VerticalDivider(),
                              Expanded(
                                child: FocusTraversalGroup(
                                  child: LibraryScreen(
                                    controller: controller,
                                    onSettings: _toggleSettings,
                                    wide: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      page = SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: FocusTraversalGroup(
              child: controller.tab == 0
                  ? HomeScreen(controller: controller, onSettings: _toggleSettings)
                  : LibraryScreen(controller: controller, onSettings: _toggleSettings),
            ),
          ),
        ),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: NazzilTheme.overlay(theme.brightness, theme.colorScheme.surface),
      // Settings is drawn in this page's place and is no route of its own, so the
      // phone's Back has to be told about it, or it would leave the app from there.
      // On the first page Back puts the app behind and leaves it running. Left to
      // the phone, Back ends an app that a share opened, and a download with it.
      child: PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_settings) {
            _toggleSettings();
          } else {
            DownloadHost.toBack();
          }
        },
        child: DesktopInput(
          controller: controller,
          child: Scaffold(
            // The tabs sit in this slot so a snack bar floats above them, not over them.
            bottomNavigationBar: _settings || wide
                ? null
                : FocusTraversalGroup(child: _Tabs(controller: controller)),
            body: page,
          ),
        ),
      ),
    );
  }
}

/// Home and Library, along the bottom of a phone.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.controller});
  final NazzilController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = [
      (s.home, Icons.home_outlined, Icons.home_rounded),
      (s.library, Icons.photo_library_outlined, Icons.photo_library_rounded),
    ];
    final link = NazzilTheme.link(theme.brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final active = controller.tab == i;
                          // The open tab is told apart by a filled icon as well as by the accent.
                          final ink = active ? link : scheme.onSurfaceVariant;
                          return Tappable(
                            onTap: () => controller.goTab(i),
                            selected: active,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 56),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(active ? items[i].$3 : items[i].$2, size: 25, color: ink),
                                    const SizedBox(height: 3),
                                    Text(
                                      items[i].$1,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.labelSmall?.copyWith(color: ink),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
