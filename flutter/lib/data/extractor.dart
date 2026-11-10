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

String friendlyError(Object error) {
  if (error is CancelledException || error is PausedException) return '';
  final text = error.toString();
  final lower = text.toLowerCase();
  if (lower.contains('socket') ||
      lower.contains('timeout') ||
      lower.contains('network') ||
      lower.contains('failed host')) {
    return 'Connection dropped. Try again.';
  }
  if (lower.contains('blocked') ||
      lower.contains('sign in') ||
      lower.contains('bot') ||
      lower.contains('cookies')) {
    return 'This post blocked the download. Try again.';
  }
  final cleaned = text.replaceAll(RegExp(r'^(Exception|Bad state|HttpException|FormatException):\s*'), '').trim();
  if (cleaned.startsWith('http') && cleaned.contains('://')) {
    return 'Could not download this. Try again.';
  }
  return cleaned.length > 140 ? '${clipUtf16(cleaned, 140)}…' : (cleaned.isEmpty ? 'Could not load this link' : cleaned);
}
