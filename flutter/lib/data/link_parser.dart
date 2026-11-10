import 'dart:io';

import '../models/media.dart';
import 'net.dart';

class LinkParser {
  static final _url = RegExp(r'''https?://[^\s<>"'\\]+''', caseSensitive: false);
  static final _loose = RegExp(
    r'''(?<![\w.-])(?:https?://)?(?:(?:www|m|vm|vt|v|old|new|mobile)\.)?(?:tiktok\.com|musical\.ly|instagram\.com|instagr\.am|facebook\.com|fb\.watch|fb\.com|music\.youtube\.com|youtube\.com|youtu\.be|x\.com|twitter\.com|reddit\.com|redd\.it)/[^\s<>"'\\]+''',
    caseSensitive: false,
  );
  static const _shortHosts = {
    'vm.tiktok.com',
    'vt.tiktok.com',
    'v.tiktok.com',
    'fb.watch',
    'fb.me',
    'l.instagram.com',
    'instagr.am',
    'ig.me',
    'youtu.be',
    't.co',
    'redd.it',
    'v.redd.it',
  };

  static String extract(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return '';
    final found = _url.firstMatch(raw)?.group(0) ?? _loose.firstMatch(raw)?.group(0);
    final cleaned = (found ?? '').replaceAll(RegExp(r'''[.,;)\]]+$'''), '');
    if (cleaned.isNotEmpty) {
      return cleaned.startsWith('http') ? cleaned : 'https://$cleaned';
    }
    for (final line in raw.split(RegExp(r'\s+'))) {
      if (looksLikeUrl(line)) {
        return line.startsWith('http') ? line : 'https://$line';
      }
    }
    return '';
  }

  static Future<String> resolve(String text) async {
    final url = extract(text);
    if (url.isEmpty) return text.trim();
    final host = Uri.tryParse(url)?.host.toLowerCase().replaceFirst('www.', '') ?? '';
    final reddit = _isReddit(host);
    final needs = _shortHosts.contains(host) ||
        url.toLowerCase().contains('/share/') ||
        (reddit && url.contains('/s/')) ||
        host.startsWith('lm.facebook') ||
        host == 'm.facebook.com';
    if (!needs) return url;
    // Reddit turns away unknown clients but serves link-preview bots.
    return await follow(url, userAgent: reddit ? NetHints.botUa : NetHints.mobileUa) ?? url;
  }

  static bool looksLikeUrl(String value) {
    final text = value.toLowerCase();
    return text.startsWith('http://') ||
        text.startsWith('https://') ||
        text.contains('tiktok.com') ||
        text.contains('instagram.com') ||
        text.contains('facebook.com') ||
        text.contains('fb.watch') ||
        text.contains('youtu.be') ||
        text.contains('x.com/') ||
        text.contains('twitter.com/') ||
        text.contains('reddit.com/') ||
        text.contains('redd.it/') ||
        text.contains('youtube.com');
  }

  static PlatformId platformOf(String url) {
    final host = url.toLowerCase();
    if (host.contains('youtu')) return PlatformId.youtube;
    if (host.contains('tiktok') || host.contains('musical.ly')) {
      return PlatformId.tiktok;
    }
    if (host.contains('instagram') || host.contains('instagr.am')) {
      return PlatformId.instagram;
    }
    if (host.contains('facebook') || host.contains('fb.watch') || host.contains('fb.com')) {
      return PlatformId.facebook;
    }
    final name = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
    if (_isReddit(name)) return PlatformId.reddit;
    if (_isX(name)) return PlatformId.x;
    return PlatformId.unknown;
  }

  static bool _isReddit(String host) =>
      host == 'reddit.com' || host.endsWith('.reddit.com') || host == 'redd.it' || host.endsWith('.redd.it');

  static bool _isX(String host) {
    final bare = host.startsWith('www.') ? host.substring(4) : host;
    return const {'x.com', 'twitter.com', 'mobile.twitter.com', 'mobile.x.com', 't.co', 'fxtwitter.com', 'vxtwitter.com', 'fixupx.com', 'fixvx.com'}
        .contains(bare);
  }

  static String? tweetId(String url) {
    if (!_isX(Uri.tryParse(url.trim())?.host.toLowerCase() ?? '')) return null;
    return RegExp(r'/status(?:es)?/(\d+)').firstMatch(url)?.group(1);
  }

  static String? redditId(String url) {
    if (!_isReddit(Uri.tryParse(url.trim())?.host.toLowerCase() ?? '')) return null;
    return RegExp(r'/comments/([a-z0-9]+)', caseSensitive: false).firstMatch(url)?.group(1)?.toLowerCase() ??
        RegExp(r'^https?://(?:www\.)?redd\.it/([a-z0-9]+)', caseSensitive: false).firstMatch(url)?.group(1)?.toLowerCase();
  }

  static bool isSupported(String url) => platformOf(url) != PlatformId.unknown;

  static String? youtubeId(String url) {
    return RegExp(r'(?:youtu\.be/|v=|shorts/|embed/|live/|/v/)([A-Za-z0-9_-]{11})')
        .firstMatch(url)
        ?.group(1);
  }

  static String? tiktokId(String url) {
    return RegExp(r'/(?:video|photo)/(\d+)').firstMatch(url)?.group(1);
  }

  static String? instagramCode(String url) {
    return RegExp(r'instagram\.com/(?:reel|reels|p|tv)/([A-Za-z0-9_-]+)', caseSensitive: false)
        .firstMatch(url)
        ?.group(1);
  }

  static bool isTikTokPhotoUrl(String url) {
    return url.toLowerCase().contains('/photo/');
  }

  static String identityKey(String url, [String? id]) {
    final yt = youtubeId(url);
    if (yt != null) return 'yt:$yt';
    final tt = tiktokId(url);
    if (tt != null) return 'tt:$tt';
    final ig = instagramCode(url);
    if (ig != null) return 'ig:$ig';
    final tweet = tweetId(url);
    if (tweet != null) return 'x:$tweet';
    final post = redditId(url);
    if (post != null) return 'rd:$post';
    final fb = RegExp(r'(?:videos|reel)/(\d+)|[?&]v=(\d+)').firstMatch(url);
    final fbId = fb?.group(1) ?? fb?.group(2);
    if (fbId != null) return 'fb:$fbId';
    if (id != null && id.isNotEmpty && !_looksLikeTimestamp(id)) {
      final prefix = switch (platformOf(url)) {
        PlatformId.youtube => 'yt',
        PlatformId.tiktok => 'tt',
        PlatformId.instagram => 'ig',
        PlatformId.facebook => 'fb',
        PlatformId.reddit => 'rd',
        PlatformId.x => 'x',
        PlatformId.unknown => 'id',
      };
      return '$prefix:$id';
    }
    return 'url:${url.toLowerCase().split('?').first}';
  }

  static bool _looksLikeTimestamp(String id) =>
      id.length >= 12 && RegExp(r'^\d+$').hasMatch(id);

  static String sanitizeFilename(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
    if (cleaned.isEmpty) return 'nazzil';
    return clipUtf16(cleaned, 60).trimRight();
  }

  static Future<String?> follow(String start, {String userAgent = NetHints.mobileUa}) async {
    var current = start;
    final client = HttpClient();
    try {
      for (var i = 0; i < 8; i++) {
        final request = await client.getUrl(Uri.parse(current));
        request.followRedirects = false;
        request.headers.set(HttpHeaders.userAgentHeader, userAgent);
        final response = await request.close();
        await response.drain<void>();
        if (response.statusCode < 300 || response.statusCode >= 400) {
          return current;
        }
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null || location.isEmpty) return current;
        current = Uri.parse(current).resolve(location).toString();
      }
      return current;
    } catch (_) {
      return current;
    } finally {
      client.close(force: true);
    }
  }
}

class NetHints {
  static const mobileUa =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';
  static const desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';
  static const botUa = 'Mozilla/5.0 (compatible; Discordbot/2.0; +https://discordapp.com)';
  static const facebookUa =
      'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)';
}
