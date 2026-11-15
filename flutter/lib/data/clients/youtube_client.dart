import '../../models/media.dart';
import '../link_parser.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeClient {
  /// Tried one at a time: asking for several at once makes the library query
  /// all of them even after the first one works.
  static final _clients = <YoutubeApiClient>[
    YoutubeApiClient.androidSdkless,
    YoutubeApiClient.androidVr,
    YoutubeApiClient.ios,
    YoutubeApiClient.tv,
  ];

  /// The app client a googlevideo link was given to, which the link names in `c`.
  static String? clientOf(Uri? link) =>
      link != null && link.host.endsWith('googlevideo.com') ? link.queryParameters['c'] : null;

  static String _nameOf(YoutubeApiClient client) => client.payload['context']['client']['clientName'] as String;

  /// [refused] holds the app clients, as [clientOf] names them, whose links YouTube would not serve.
  Future<MediaInfo> fetch(String url, {Set<String> refused = const {}}) async {
    final id = LinkParser.youtubeId(url);
    if (id == null) throw StateError('Could not read this YouTube link');
    final watch = 'https://www.youtube.com/watch?v=$id';
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(id);
      final manifest = await _manifest(yt, id, refused);
      final options = optionsFrom(manifest);
      if (options.isEmpty) throw StateError('No downloadable YouTube video');
      return MediaInfo(
        id: id,
        title: video.title,
        author: video.author,
        thumbnail: video.thumbnails.highResUrl,
        duration: video.duration?.inSeconds,
        webpageUrl: watch,
        platform: PlatformId.youtube,
        options: options,
      );
    } finally {
      yt.close();
    }
  }

  Future<StreamManifest> _manifest(YoutubeExplode yt, String id, Set<String> refused) async {
    Object? last;
    for (final client in _clients) {
      if (refused.contains(_nameOf(client))) continue;
      try {
        final manifest = await yt.videos.streams.getManifest(id, ytClients: [client]);
        if (manifest.streams.isNotEmpty) return manifest;
      } catch (error) {
        last = error;
      }
    }
    throw last ?? StateError('No downloadable YouTube video');
  }

  /// Phones and iPhones play H.264 + AAC in MP4 everywhere, and joining the
  /// two needs no re-encoding, so HD sticks to avc1 video up to 1080p.
  static List<QualityOption> optionsFrom(StreamManifest manifest) {
    final aac = manifest.audioOnly.where((s) => s.container == StreamContainer.mp4).toList()
      ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
    final avc = manifest.videoOnly
        .where((s) => s.container == StreamContainer.mp4 && s.videoCodec.startsWith('avc1'))
        .where((s) => s.videoResolution.height <= 1080)
        .toList()
      ..sort((a, b) {
        final byHeight = b.videoResolution.height.compareTo(a.videoResolution.height);
        return byHeight != 0 ? byHeight : b.framerate.framesPerSecond.compareTo(a.framerate.framesPerSecond);
      });
    final muxed = manifest.muxed.toList()
      ..sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));
    final audios = manifest.audioOnly.toList()..sort((a, b) => b.bitrate.compareTo(a.bitrate));

    final options = <QualityOption>[];
    final bestMuxed = muxed.isEmpty ? 0 : muxed.first.videoResolution.height;
    if (avc.isNotEmpty && aac.isNotEmpty && avc.first.videoResolution.height > bestMuxed) {
      final hd = avc.first;
      options.add(QualityOption(
        id: 'yt-hd-${hd.videoResolution.height}',
        label: 'HD',
        ext: 'mp4',
        kind: MediaKind.video,
        height: hd.videoResolution.height,
        directUrl: hd.url.toString(),
        audioUrl: aac.first.url.toString(),
      ));
    } else if (muxed.isNotEmpty) {
      options.add(_single('yt-hd', 'HD', muxed.first));
    }
    final sd = muxed.where((s) => s.videoResolution.height <= 480).firstOrNull;
    if (sd != null && options.every((o) => o.directUrl != sd.url.toString())) {
      options.add(_single('yt-sd', 'SD', sd));
    } else if (options.isNotEmpty && aac.isNotEmpty) {
      final low = avc.where((s) => s.videoResolution.height <= 480).firstOrNull;
      if (low != null) {
        options.add(QualityOption(
          id: 'yt-sd-${low.videoResolution.height}',
          label: 'SD',
          ext: 'mp4',
          kind: MediaKind.video,
          height: low.videoResolution.height,
          directUrl: low.url.toString(),
          audioUrl: aac.first.url.toString(),
        ));
      }
    }
    if (audios.isNotEmpty) {
      options.add(QualityOption(
        id: 'yt-audio',
        label: 'Audio',
        ext: audios.first.container == StreamContainer.mp4 ? 'm4a' : audios.first.container.name,
        kind: MediaKind.audio,
        directUrl: audios.first.url.toString(),
      ));
    }
    return options;
  }

  static QualityOption _single(String prefix, String label, MuxedStreamInfo stream) {
    return QualityOption(
      id: '$prefix-${stream.videoResolution.height}',
      label: label,
      ext: stream.container.name,
      kind: MediaKind.video,
      height: stream.videoResolution.height,
      directUrl: stream.url.toString(),
    );
  }
}
