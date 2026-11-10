import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/downloader.dart';
import '../../data/host.dart';
import '../../data/platforms.dart';
import '../../models/media.dart';
import '../../theme/nazzil_theme.dart';

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.item});
  final LibraryItem item;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  VideoPlayerController? _player;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.item.kind != MediaKind.photo && Platforms.inAppVideo) {
      final path = widget.item.primaryPath;
      if (path != null && File(path).existsSync()) {
        _player = VideoPlayerController.file(File(path))
          ..initialize().then((_) {
            if (!mounted) return;
            setState(() {});
            _player?.play();
          });
      }
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: item.kind == MediaKind.photo ? Colors.black : null,
      appBar: AppBar(
        backgroundColor: item.kind == MediaKind.photo ? Colors.black : null,
        foregroundColor: item.kind == MediaKind.photo ? Colors.white : null,
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: item.kind == MediaKind.photo ? _photos(item) : _video(),
    );
  }

  Widget _photos(LibraryItem item) {
    final paths = item.paths.where((p) => File(p).existsSync()).toList();
    if (paths.isEmpty) {
      return const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54));
    }
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            itemCount: paths.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              if (isVideoFile(File(paths[i]))) {
                if (!Platforms.inAppVideo) return _ExternalVideo(path: paths[i]);
                return _AlbumVideo(key: ValueKey(paths[i]), path: paths[i], active: i == _index);
              }
              return InteractiveViewer(
                child: Image.file(File(paths[i]), fit: BoxFit.contain),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: NazzilColors.lilac.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_index + 1} / ${paths.length}',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
                color: NazzilColors.lilac,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _video() {
    if (!Platforms.inAppVideo) {
      final path = widget.item.primaryPath;
      if (path == null) return const SizedBox.shrink();
      return _ExternalVideo(path: path);
    }
    final player = _player;
    if (player == null || !player.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: NazzilColors.rose));
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          player.value.isPlaying ? player.pause() : player.play();
        });
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: player.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(player),
              if (!player.value.isPlaying)
                const Icon(Icons.play_circle, size: 72, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumVideo extends StatefulWidget {
  const _AlbumVideo({super.key, required this.path, required this.active});
  final String path;
  final bool active;

  @override
  State<_AlbumVideo> createState() => _AlbumVideoState();
}

class _AlbumVideoState extends State<_AlbumVideo> {
  late final VideoPlayerController _player = VideoPlayerController.file(File(widget.path));

  @override
  void initState() {
    super.initState();
    _player.initialize().then((_) {
      if (mounted) setState(() {});
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
    if (!_player.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: NazzilColors.lilac));
    }
    return GestureDetector(
      onTap: () => setState(() => _player.value.isPlaying ? _player.pause() : _player.play()),
      child: Center(
        child: AspectRatio(
          aspectRatio: _player.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_player),
              if (!_player.value.isPlaying) const Icon(Icons.play_circle, size: 72, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExternalVideo extends StatelessWidget {
  const _ExternalVideo({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 88,
            color: NazzilColors.rose,
            icon: const Icon(Icons.play_circle),
            onPressed: () => DownloadHost.openFile(path),
          ),
          const SizedBox(height: 8),
          Text(
            path.split(Platform.pathSeparator).last,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
