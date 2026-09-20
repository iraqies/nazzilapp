import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/strings.dart';
import 'models/media.dart';
import 'state/nazzil_controller.dart';
import 'theme/nazzil_theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/viewer_screen.dart';
import 'ui/widgets/done_sheet.dart';
import 'ui/widgets/glow_backdrop.dart';

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
          theme: NazzilTheme.light(),
          darkTheme: NazzilTheme.dark(),
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
          builder: (context) => DoneSheet(
            s: s,
            photos: done.kind == MediaKind.photo,
            onView: () {
              Navigator.pop(context);
              widget.controller.dismissSheets();
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => ViewerScreen(item: done)),
              );
            },
            onShare: () {
              Navigator.pop(context);
              widget.controller.shareItem(done);
              widget.controller.dismissSheets();
            },
            onClose: () {
              Navigator.pop(context);
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
        builder: (context) => AlertDialog(
          title: Text(s.alreadyHave),
          content: Text(s.alreadyHaveBody),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.controller.dismissSheets();
              },
              child: Text(s.close),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.controller.dismissSheets();
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => ViewerScreen(item: dup)),
                );
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
    final s = controller.s;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: GlowBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 10, 6),
                  child: Row(
                    children: [
                      const Mark(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _settings ? s.settings : s.appName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        controller.downloading
                            ? (controller.queuedCount > 0
                                ? '${s.downloading} · ${s.waitingN(controller.queuedCount)}'
                                : s.downloading)
                            : controller.library.any((e) => e.paused)
                                ? s.paused
                            : controller.loading
                                ? s.fetching
                                : s.ready,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: controller.downloading ||
                                      controller.loading ||
                                      controller.library.any((e) => e.paused)
                                  ? NazzilColors.rose
                                  : NazzilColors.mint,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _settings = !_settings),
                        icon: Icon(_settings ? Icons.arrow_back_rounded : Icons.settings_outlined),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _settings
                      ? SettingsScreen(controller: controller)
                      : controller.tab == 0
                          ? HomeScreen(controller: controller)
                          : LibraryScreen(controller: controller),
                ),
                if (!_settings) _Tabs(controller: controller, s: s),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.controller, required this.s});
  final NazzilController controller;
  final S s;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (s.home, Icons.home_outlined),
      (s.library, Icons.photo_library_outlined),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: scheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    decoration: BoxDecoration(
                      color: controller.tab == i ? NazzilColors.rose : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        if (controller.tab != i) controller.goTab(i);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              items[i].$2,
                              size: 16,
                              color: controller.tab == i ? Colors.white : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              items[i].$1,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: controller.tab == i ? Colors.white : scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
