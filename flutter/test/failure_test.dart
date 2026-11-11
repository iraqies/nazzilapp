import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/data/extractor.dart';
import 'package:nazzil/l10n/strings.dart';
import 'package:nazzil/models/media.dart';

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
