import '../../models/media.dart';
import '../link_parser.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeClient {
  Future<MediaInfo> fetch(String url) async {
    final id = LinkParser.youtubeId(url);
    if (id == null) throw StateError('Could not read this YouTube link');
    final watch = 'https://www.youtube.com/watch?v=$id';
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(id);
      final manifest = await yt.videos.streamsClient.getManifest(id);
      final muxed = manifest.muxed.toList()
        ..sort((a, b) => (b.videoResolution.height).compareTo(a.videoResolution.height));
      final audios = manifest.audioOnly.toList()
        ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
      if (muxed.isEmpty) {
        throw StateError('No downloadable YouTube video');
      }
      final hd = muxed.firstWhere(
        (s) => s.videoResolution.height >= 720,
        orElse: () => muxed.first,
      );
      QualityOption? sd;
      for (final stream in muxed.reversed) {
        if (stream.videoResolution.height <= 480 && stream.url != hd.url) {
          sd = QualityOption(
            id: 'yt-sd-${stream.videoResolution.height}',
            label: 'SD',
            ext: stream.container.name,
            kind: MediaKind.video,
            height: stream.videoResolution.height,
            directUrl: stream.url.toString(),
          );
          break;
        }
      }
      if (sd == null && muxed.length > 1) {
        final low = muxed.last;
        sd = QualityOption(
          id: 'yt-sd-${low.videoResolution.height}',
          label: 'SD',
          ext: low.container.name,
          kind: MediaKind.video,
          height: low.videoResolution.height,
          directUrl: low.url.toString(),
        );
      }
      final options = <QualityOption>[
        QualityOption(
          id: 'yt-hd-${hd.videoResolution.height}',
          label: 'HD',
          ext: hd.container.name,
          kind: MediaKind.video,
          height: hd.videoResolution.height,
          directUrl: hd.url.toString(),
        ),
        if (sd != null && sd.directUrl != hd.url.toString()) sd,
        if (audios.isNotEmpty)
          QualityOption(
            id: 'yt-audio',
            label: 'Audio',
            ext: audios.first.container.name == 'mp4' ? 'm4a' : audios.first.container.name,
            kind: MediaKind.audio,
            directUrl: audios.first.url.toString(),
          ),
      ];
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
}
