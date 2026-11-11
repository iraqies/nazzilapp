import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/data/clients/pinterest_client.dart';
import 'package:nazzil/data/clients/reddit_client.dart';
import 'package:nazzil/data/clients/x_client.dart';
import 'package:nazzil/data/extractor.dart';
import 'package:nazzil/data/link_parser.dart';
import 'package:nazzil/data/net.dart';
import 'package:nazzil/l10n/strings.dart';
import 'package:nazzil/models/media.dart';

/// Every request ends the way [error] says.
class _DeadNet extends NetClient {
  _DeadNet(this.error);
  final Object error;

  @override
  Future<String> get(String url, {Map<String, String> headers = const {}, String userAgent = NetHints.mobileUa}) async =>
      throw error;
}

void main() {
  test('sorts the messages the data layer throws', () {
    const cases = {
      'Gallery permission is needed to save.': Failure.permission,
      'This Reddit video is still processing.': Failure.processing,
      'Could not put the video and sound together.': Failure.convert,
      'Could not make the video.': Failure.convert,
      'Could not turn this into an MP3.': Failure.convert,
      'This link is not from a supported app yet.': Failure.unsupported,
      'Unsupported link': Failure.unsupported,
      'This X link does not point to a post.': Failure.badLink,
      'This Pinterest link does not point to a pin.': Failure.badLink,
      'Could not read this YouTube link': Failure.badLink,
      'Could not load this pin. It may be private or deleted.': Failure.unavailable,
      'Could not read this TikTok post. Make sure it is public.': Failure.unavailable,
      'Instagram did not share this post. It may be private, or Instagram wants a login right now.':
          Failure.unavailable,
      'This Reddit gallery is empty or removed.': Failure.unavailable,
      'This post is gone.': Failure.unavailable,
      "VideoUnavailableException: Video 'abc' is unavailable\n"
          "In most cases, this error indicates that the video doesn't exist, is private, or has been taken down.":
          Failure.unavailable,
      'This X post has no video or photos.': Failure.noMedia,
      'This pin has no video or image.': Failure.noMedia,
      'No photos on this post': Failure.noMedia,
      'No downloadable YouTube video': Failure.noMedia,
      'Instagram embed had no media': Failure.noMedia,
      'This Instagram post has nothing to download.': Failure.noMedia,
      'This post blocked the download. Try again.': Failure.blocked,
      "Sign in to confirm you're not a bot": Failure.blocked,
      'Could not load this Facebook link': Failure.load,
      'TikTok lookup failed': Failure.load,
    };
    for (final entry in cases.entries) {
      expect(failureOf(StateError(entry.key)), entry.value, reason: entry.key);
    }
  });

  test('network trouble, raw text and stops', () {
    expect(failureOf(const SocketException('Failed host lookup')), Failure.network);
    expect(failureOf(const HttpException('Connection closed before full header was received')), Failure.network);
    expect(failureOf(const HttpException('HTTP 500')), Failure.load);
    expect(failureOf(const HttpException('HTTP 500'), downloading: true), Failure.download);
    expect(failureOf(const FormatException('Unexpected character (at offset 3)')), Failure.load);
    expect(failureOf(CancelledException()), Failure.none);
    expect(failureOf(const PausedException()), Failure.none);
  });

  test('every failure is worded in both languages, with no raw text', () {
    for (final kind in Failure.values) {
      final en = const S('en').failure(kind);
      final ar = const S('ar').failure(kind);
      if (kind == Failure.none) {
        expect(en, isEmpty);
        expect(ar, isEmpty);
        continue;
      }
      expect(en, isNotEmpty, reason: kind.name);
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(ar), isTrue, reason: kind.name);
      expect(RegExp(r'[A-Za-z]').hasMatch(ar), isFalse, reason: kind.name);
      expect(RegExp(r'[A-Za-z]').hasMatch(const S('ar').failureLine(kind)), isFalse, reason: kind.name);
    }
  });

  test('the retry advice is left off where a retry button sits beside the text', () {
    const s = S('en');
    expect(s.failure(Failure.network), 'Connection dropped.');
    expect(s.failureLine(Failure.network), 'Connection dropped. Try again.');
    expect(s.failureLine(Failure.blocked), 'This post blocked the download. Try again later.');
    expect(s.failureLine(Failure.unavailable), 'This post may be private or deleted.');
    expect(const S('ar').failureLine(Failure.processing), 'هذا الفيديو ما زال قيد المعالجة. حاول بعد قليل.');
  });

  test('a stored failure name survives a round trip, and old text falls back', () {
    expect(Failure.named(Failure.network.name), Failure.network);
    expect(Failure.named('Connection dropped. Try again.'), Failure.download);
  });

  test('with no connection a client says so, and does not blame the post', () async {
    Future<Failure> failureFrom(Future<MediaInfo> Function(NetClient net) fetch, Object error) async {
      final net = _DeadNet(error);
      addTearDown(net.close);
      try {
        await fetch(net);
      } catch (caught) {
        return failureOf(caught);
      }
      return Failure.none;
    }

    final fetches = <String, Future<MediaInfo> Function(NetClient net)>{
      'x': (net) => XClient(net).fetch('https://x.com/a/status/42'),
      'pinterest': (net) => PinterestClient(net).fetch('https://www.pinterest.com/pin/255016397643256616/'),
      'reddit': (net) => RedditClient(net).fetch('https://www.reddit.com/comments/abc12'),
    };
    const down = [
      SocketException("Failed host lookup: 'example.com'"),
      HttpException('Connection closed before full header was received'),
      HandshakeException('Connection terminated during handshake'),
    ];
    for (final MapEntry(key: name, value: fetch) in fetches.entries) {
      for (final error in down) {
        expect(await failureFrom(fetch, error), Failure.network, reason: '$name, $error');
      }
    }

    // The server answering "not found" is still about the post.
    const gone = HttpException('HTTP 404');
    expect(await failureFrom(fetches['x']!, gone), Failure.unavailable);
    expect(await failureFrom(fetches['pinterest']!, gone), Failure.unavailable);
    expect(await failureFrom(fetches['reddit']!, gone), Failure.load);
  });

  test('interface text holds no dash characters', () {
    final source = File('lib/l10n/strings.dart').readAsStringSync();
    expect(source.contains('\u2014'), isFalse);
    expect(source.contains('\u2013'), isFalse);
  });

  test('clock formats seconds', () {
    const s = S('en');
    expect(s.clock(75), '1:15');
    expect(s.clock(5), '0:05');
    expect(s.clock(3723), '1:02:03');
  });
}
