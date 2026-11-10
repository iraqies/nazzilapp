import '../models/media.dart';
import 'clients/facebook_client.dart';
import 'clients/instagram_client.dart';
import 'clients/pinterest_client.dart';
import 'clients/reddit_client.dart';
import 'clients/tiktok_client.dart';
import 'clients/x_client.dart';
import 'clients/youtube_client.dart';
import 'link_parser.dart';
import 'net.dart';

class MediaExtractor {
  MediaExtractor({NetClient? net}) : net = net ?? NetClient();

  final NetClient net;
  late final _tiktok = TikTokClient(net);
  late final _instagram = InstagramClient(net);
  late final _facebook = FacebookClient(net);
  late final _reddit = RedditClient(net);
  late final _x = XClient(net);
  late final _pinterest = PinterestClient(net);
  final _youtube = YouTubeClient();

  Future<MediaInfo> fetch(String rawUrl) async {
    final resolved = await LinkParser.resolve(rawUrl);
    if (!LinkParser.isSupported(resolved)) {
      throw StateError('This link is not from a supported app yet.');
    }
    return switch (LinkParser.platformOf(resolved)) {
      PlatformId.tiktok => _tiktok.fetch(resolved),
      PlatformId.youtube => _youtube.fetch(resolved),
      PlatformId.instagram => _instagram.fetch(resolved),
      PlatformId.facebook => _facebook.fetch(resolved),
      PlatformId.reddit => _reddit.fetch(resolved),
      PlatformId.x => _x.fetch(resolved),
      PlatformId.pinterest => _pinterest.fetch(resolved),
      PlatformId.unknown => throw StateError('Unsupported link'),
    };
  }

  String refererFor(String url) {
    final host = url.toLowerCase();
    if (host.contains('tikwm')) return 'https://www.tikwm.com/';
    if (host.contains('tiktok')) return 'https://www.tiktok.com/';
    if (host.contains('instagram') || host.contains('cdninstagram') || host.contains('fbcdn')) {
      return 'https://www.instagram.com/';
    }
    if (host.contains('youtu') || host.contains('googlevideo')) {
      return 'https://www.youtube.com/';
    }
    if (host.contains('redd.it') || host.contains('reddit')) return 'https://www.reddit.com/';
    if (host.contains('pinimg.com') || host.contains('pinterest')) return 'https://www.pinterest.com/';
    if (host.contains('twimg.com') || host.contains('x.com') || host.contains('twitter')) return 'https://x.com/';
    return 'https://www.facebook.com/';
  }
}

Failure failureOf(Object error, {bool downloading = false}) {
  if (error is CancelledException || error is PausedException) return Failure.none;
  final text = error.toString().toLowerCase();
  bool has(List<Pattern> parts) => parts.any(text.contains);
  if (has(const ['permission'])) return Failure.permission;
  if (has(const ['still processing'])) return Failure.processing;
  if (has(const ['sound together', 'could not make the video', 'into an mp3'])) return Failure.convert;
  if (has(const ['not from a supported app', 'unsupported link'])) return Failure.unsupported;
  if (has(['does not point to', RegExp(r'could not read this \w+ link')])) return Failure.badLink;
  if (has(const ['private', 'deleted', 'removed', 'is gone', 'is public', 'did not share'])) {
    return Failure.unavailable;
  }
  if (has(const ['no video', 'no photos', 'no media', 'no downloadable', 'nothing to download'])) {
    return Failure.noMedia;
  }
  if (has(const ['socket', 'timeout', 'timed out', 'network', 'failed host', 'connection', 'handshake'])) {
    return Failure.network;
  }
  if (has(['blocked', 'sign in', 'login', 'cookies', RegExp(r'\bbot\b')])) return Failure.blocked;
  return downloading ? Failure.download : Failure.load;
}
