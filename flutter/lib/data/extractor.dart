import '../models/media.dart';
import 'clients/cobalt_client.dart';
import 'clients/facebook_client.dart';
import 'clients/instagram_client.dart';
import 'clients/tiktok_client.dart';
import 'clients/youtube_client.dart';
import 'link_parser.dart';
import 'net.dart';

class MediaExtractor {
  MediaExtractor({NetClient? net}) : net = net ?? NetClient();

  final NetClient net;
  late final _tiktok = TikTokClient(net);
  late final _instagram = InstagramClient(net);
  late final _facebook = FacebookClient(net);
  late final _cobalt = CobaltClient(net);
  final _youtube = YouTubeClient();

  Future<MediaInfo> fetch(String rawUrl) async {
    final resolved = await LinkParser.resolve(rawUrl);
    if (!LinkParser.isSupported(resolved)) {
      throw StateError('This link is not from a supported app yet.');
    }
    final platform = LinkParser.platformOf(resolved);
    try {
      return switch (platform) {
        PlatformId.tiktok => await _tiktok.fetch(resolved),
        PlatformId.youtube => await _youtube.fetch(resolved),
        PlatformId.instagram => await _instagram.fetch(resolved),
        PlatformId.facebook => await _facebook.fetch(resolved),
        PlatformId.unknown => throw StateError('Unsupported link'),
      };
    } catch (error) {
      if (platform == PlatformId.tiktok) {
        // Photo posts should not fall back to a video file from Cobalt.
        if (LinkParser.isTikTokPhotoUrl(resolved) ||
            error.toString().toLowerCase().contains('photo')) {
          rethrow;
        }
      }
      if (platform == PlatformId.instagram && resolved.contains('/p/')) {
        rethrow;
      }
      try {
        return await _cobalt.fetch(resolved, platform);
      } catch (_) {
        throw error;
      }
    }
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
  final cleaned = text.replaceAll(RegExp(r'^Exception:\s*'), '').trim();
  if (cleaned.startsWith('http') && cleaned.contains('://')) {
    return 'Could not download this. Try again.';
  }
  return cleaned.length > 140 ? '${cleaned.substring(0, 140)}…' : (cleaned.isEmpty ? 'Could not load this link' : cleaned);
}
