import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../data/downloader.dart';
import '../../data/host.dart';
import '../../data/platforms.dart';
import '../../l10n/strings.dart';
import '../../models/media.dart';
import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';
import '../widgets/page_stepper.dart';
import '../widgets/state_message.dart';
import '../widgets/tappable.dart';
import '../widgets/title_text.dart';

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.controller, required this.item});
  final NazzilController controller;
  final LibraryItem item;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  VideoPlayerController? _player;
  final _pages = PageController();
  bool _failed = false;
  int _index = 0;

  S get _s => widget.controller.s;

  @override
  void initState() {
    super.initState();
    final path = widget.item.primaryPath;
    if (widget.item.kind == MediaKind.photo || !Platforms.inAppVideo) return;
    if (path == null || !File(path).existsSync()) return;
    final player = VideoPlayerController.file(File(path));
    _player = player;
    player.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      player.play();
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final photo = item.kind == MediaKind.photo;
    return Scaffold(
      backgroundColor: photo ? Colors.black : null,
      appBar: AppBar(
        backgroundColor: photo ? Colors.black : null,
        foregroundColor: photo ? Colors.white : null,
        title: TitleText(
          item.title,
          maxLines: 1,
          style: photo ? Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white) : null,
        ),
      ),
      body: photo ? _photos(item) : _video(),
    );
  }

  Widget _gone({bool onPhoto = false}) {
    final item = widget.item;
    return StateMessage(
      onPhoto: onPhoto,
      title: _s.fileGone,
      actions: [
        (
          _s.downloadAgain,
          () {
            Navigator.pop(context);
            widget.controller.retryJob(item);
          },
        ),
        (_s.original, () => widget.controller.openOriginal(item.sourceUrl)),
      ],
    );
  }

  Widget _photos(LibraryItem item) {
    final paths = item.paths.where((p) => File(p).existsSync()).toList();
    if (paths.isEmpty) return _gone(onPhoto: true);
    void go(int page) {
      if (page < 0 || page >= paths.length) return;
      if (NazzilMotion.reduced(context)) {
        _pages.jumpToPage(page);
      } else {
        _pages.animateToPage(page, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
      }
    }

    // The arrow that points the reading way goes to the next photo.
    final forward = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => go(_index + forward),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => go(_index - forward),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: paths.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  if (isVideoFile(File(paths[i]))) {
                    if (!Platforms.inAppVideo) return _ExternalVideo(path: paths[i], s: _s, onPhoto: true);
                    return _AlbumVideo(key: ValueKey(paths[i]), path: paths[i], active: i == _index, s: _s);
                  }
                  return InteractiveViewer(
                    child: Image.file(
                      File(paths[i]),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => StateMessage(onPhoto: true, title: _s.photoFailed),
                    ),
                  );
                },
              ),
            ),
            if (paths.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: PageStepper(index: _index, count: paths.length, onStep: go, s: _s, onPhoto: true),
              )
            else
              const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _video() {
    final path = widget.item.primaryPath;
    if (path == null || !File(path).existsSync()) return _gone();
    if (!Platforms.inAppVideo) return _ExternalVideo(path: path, s: _s);
    final player = _player;
    if (_failed || player == null) {
      return StateMessage(
        title: _s.cantPlay,
        actions: [
          (_s.openGallery, () => DownloadHost.openFile(path)),
          (_s.original, () => widget.controller.openOriginal(widget.item.sourceUrl)),
        ],
      );
    }
    if (!player.value.isInitialized) return const Center(child: CircularProgressIndicator());
    return _PlayArea(player: player, s: _s);
  }
}

/// The video itself is the play and pause control, by tap or by keyboard.
class _PlayArea extends StatefulWidget {
  const _PlayArea({required this.player, required this.s, this.onPhoto = false});
  final VideoPlayerController player;
  final S s;
  final bool onPhoto;

  @override
  State<_PlayArea> createState() => _PlayAreaState();
}

class _PlayAreaState extends State<_PlayArea> {
  late bool _playing = widget.player.value.isPlaying;

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_sync);
  }

  @override
  void dispose() {
    widget.player.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    final playing = widget.player.value.isPlaying;
    if (playing != _playing && mounted) setState(() => _playing = playing);
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    return Center(
      child: AspectRatio(
        aspectRatio: player.value.aspectRatio,
        child: Tappable(
          radius: 0,
          ringColor: widget.onPhoto ? Colors.white : null,
          label: _playing ? widget.s.pause : widget.s.play,
          onTap: () => _playing ? player.pause() : player.play(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoPlayer(player),
              if (!_playing) const Center(child: Icon(Icons.play_circle, size: 72, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumVideo extends StatefulWidget {
  const _AlbumVideo({super.key, required this.path, required this.active, required this.s});
  final String path;
  final bool active;
  final S s;

  @override
  State<_AlbumVideo> createState() => _AlbumVideoState();
}

class _AlbumVideoState extends State<_AlbumVideo> {
  late final VideoPlayerController _player = VideoPlayerController.file(File(widget.path));
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _player.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void didUpdateWidget(covariant _AlbumVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && _player.value.isPlaying) _player.pause();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return StateMessage(
        onPhoto: true,
        title: widget.s.cantPlay,
        actions: [(widget.s.openGallery, () => DownloadHost.openFile(widget.path))],
      );
    }
    if (!_player.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return _PlayArea(player: _player, s: widget.s, onPhoto: true);
  }
}

class _ExternalVideo extends StatefulWidget {
  const _ExternalVideo({required this.path, required this.s, this.onPhoto = false});
  final String path;
  final S s;
  final bool onPhoto;

  @override
  State<_ExternalVideo> createState() => _ExternalVideoState();
}

class _ExternalVideoState extends State<_ExternalVideo> {
  bool _unopened = false;

  Future<void> _open() async {
    final opened = await DownloadHost.openFile(widget.path);
    if (mounted) setState(() => _unopened = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onPhoto = widget.onPhoto;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: widget.s.play,
            iconSize: 88,
            color: onPhoto ? Colors.white : scheme.primary,
            // Round like its icon, so hover, press and the focus ring follow the edge.
            style: ButtonStyle(
              shape: WidgetStateProperty.resolveWith(
                (states) => CircleBorder(
                  side: states.contains(WidgetState.focused)
                      ? BorderSide(
                          color: onPhoto ? Colors.white : scheme.onSurface,
                          width: 2,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        )
                      : BorderSide.none,
                ),
              ),
            ),
            icon: const Icon(Icons.play_circle),
            onPressed: _open,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.path.split(Platform.pathSeparator).last,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onPhoto ? Colors.white : scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_unopened)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  widget.s.cantOpen,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: onPhoto ? Colors.white : scheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
