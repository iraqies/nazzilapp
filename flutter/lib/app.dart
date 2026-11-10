import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/platforms.dart';
import 'models/media.dart';
import 'state/nazzil_controller.dart';
import 'theme/nazzil_theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/viewer_screen.dart';
import 'ui/widgets/desktop_input.dart';
import 'ui/widgets/done_sheet.dart';
import 'ui/widgets/mark.dart';
import 'ui/widgets/tappable.dart';

class NazzilApp extends StatelessWidget {
  const NazzilApp({super.key, required this.controller});
  final NazzilController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.s;
        final palette = NazzilPalette.byId(controller.settings.palette);
        return MaterialApp(
          title: s.appName,
          debugShowCheckedModeBanner: false,
          theme: NazzilTheme.light(palette, arabic: s.isAr),
          darkTheme: NazzilTheme.dark(palette, arabic: s.isAr),
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
  /// From this width up the link box and the library sit side by side.
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final wide = media.size.width - media.padding.horizontal >= _wide;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: DesktopInput(
        controller: controller,
        child: Scaffold(
          // The tabs sit in this slot so a snack bar floats above them, not over them.
          bottomNavigationBar: _settings || wide
              ? null
              : SafeArea(
                  top: false,
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: _Tabs(controller: controller),
                    ),
                  ),
                ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide && !_settings ? 1280 : 640),
                child: Column(
                  children: [
                    _header(context),
                    Expanded(
                      child: _settings
                          ? SettingsScreen(controller: controller)
                          : wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(width: 460, child: HomeScreen(controller: controller)),
                                    const VerticalDivider(),
                                    Expanded(
                                      child: LibraryScreen(controller: controller, showAddLink: false),
                                    ),
                                  ],
                                )
                              : controller.tab == 0
                                  ? HomeScreen(controller: controller)
                                  : LibraryScreen(controller: controller),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final controller = widget.controller;
    final s = controller.s;
    final theme = Theme.of(context);
    final working = controller.downloading || controller.loading || controller.library.any((e) => e.paused);
    final doing = controller.converting ? s.converting : s.downloading;
    final status = controller.downloading
        ? (controller.queuedCount > 0 ? '$doing · ${s.waitingN(controller.queuedCount)}' : doing)
        : controller.library.any((e) => e.paused)
            ? s.paused
            : controller.loading
                ? s.fetching
                : s.ready;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 6, 10, 6),
      child: Row(
        children: [
          const Mark(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_settings ? s.settings : s.appName, style: theme.textTheme.titleLarge),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    status,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: working ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: _settings ? s.back : s.settings,
            onPressed: () => setState(() => _settings = !_settings),
            icon: Icon(_settings ? Icons.arrow_back_rounded : Icons.settings_outlined),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.controller});
  final NazzilController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = [(s.home, Icons.home_outlined), (s.library, Icons.photo_library_outlined)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(NazzilRadius.card),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            spacing: 4,
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final active = controller.tab == i;
                      final ink = active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
                      return Tappable(
                        onTap: () => controller.goTab(i),
                        selected: active,
                        color: active ? scheme.primaryContainer : Colors.transparent,
                        side: active ? BorderSide(color: scheme.primary, width: 1.5) : BorderSide.none,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              runAlignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Icon(items[i].$2, size: 18, color: ink),
                                Text(items[i].$1, style: theme.textTheme.labelLarge?.copyWith(color: ink)),
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
    );
  }
}
