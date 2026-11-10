import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/data/clients/instagram_client.dart';
import 'package:nazzil/data/library_store.dart';
import 'package:nazzil/data/lyrics.dart';
import 'package:nazzil/data/net.dart';
import 'package:nazzil/models/media.dart';

LibraryItem _item({
  required String id,
  String status = LibraryItem.statusQueued,
}) {
  return LibraryItem(
    id: id,
    title: id,
    platform: PlatformId.youtube,
    kind: MediaKind.video,
    quality: 'HD',
    createdAt: DateTime.fromMillisecondsSinceEpoch(1),
    sourceUrl: 'https://youtu.be/aaaaaaaaaaa',
    videoKey: 'yt:aaaaaaaaaaa',
    status: status,
  );
}

Map<String, dynamic> _image(String name, int width) => {
      'image_versions2': {
        'candidates': [
          {'url': 'https://scontent.cdninstagram.com/$name-small.jpg', 'width': width ~/ 2},
          {'url': 'https://scontent.cdninstagram.com/$name.jpg', 'width': width},
        ],
      },
    };

void main() {
  test('instagram reel becomes HD, SD and audio with the caption as title', () {
    final media = InstagramClient.fromProduct({
      'media_type': 2,
      'user': {'username': 'cats'},
      'caption': {'text': 'Gingerton &amp; friends\nsecond line #cat #fyp'},
      'video_duration': 12.4,
      ..._image('cover', 1080),
      'video_versions': [
        {'type': 101, 'url': 'https://scontent.cdninstagram.com/hd.mp4?x=1'},
        {'type': 102, 'url': 'https://scontent.cdninstagram.com/sd.mp4?x=1'},
      ],
    }, code: 'abc', pageUrl: 'https://www.instagram.com/p/abc/');
    expect(media.title, 'Gingerton & friends');
    expect(media.author, 'cats');
    expect(media.duration, 12);
    expect(media.thumbnail, 'https://scontent.cdninstagram.com/cover.jpg');
    expect(media.options.map((o) => o.label), ['HD', 'SD', 'Audio']);
    expect(media.options.first.directUrl, contains('hd.mp4'));
    expect(media.photos, isEmpty);
  });

  test('instagram carousel keeps every item and marks mixed albums', () {
    final media = InstagramClient.fromProduct({
      'media_type': 8,
      'user': {'username': 'instagram'},
      'carousel_media': [
        _image('one', 1080),
        {
          ..._image('two', 720),
          'video_versions': [
            {'url': 'https://scontent.cdninstagram.com/two.mp4'},
          ],
        },
        _image('three', 1080),
      ],
    }, code: 'xyz', pageUrl: 'https://www.instagram.com/p/xyz/');
    expect(media.isPhotoAlbum, isTrue);
    expect(media.photos, hasLength(3));
    final album = media.options.single;
    expect(album.label, 'Album');
    expect(album.photoUrls[0], endsWith('one.jpg'));
    expect(album.photoUrls[1], endsWith('two.mp4'));
    expect(album.photoUrls[2], endsWith('three.jpg'));
    expect(media.title, 'Instagram post by @instagram');
  });

  test('instagram single photo is a one-photo album', () {
    final media = InstagramClient.fromProduct(
      {'media_type': 1, ..._image('solo', 1440)},
      code: 'p1',
      pageUrl: 'https://www.instagram.com/p/p1/',
    );
    expect(media.options.single.label, 'Photos');
    expect(media.options.single.photoUrls, ['https://scontent.cdninstagram.com/solo.jpg']);
  });

  test('instagram product is found inside the data-sjs relay scripts', () {
    final product = {
      'media_type': 2,
      'video_versions': [
        {'url': 'https://scontent.cdninstagram.com/v.mp4'},
      ],
    };
    final relay = jsonEncode({
      'require': [
        [
          'ScheduledServerJS',
          'handle',
          null,
          [
            {
              '__bbox': {
                'result': {
                  'data': {
                    'xig_polaris_media': {'if_not_gated_logged_out': product},
                  },
                },
              },
            },
          ],
        ],
      ],
    });
    final html = '<script type="application/json" data-sjs>{"other":1}</script>'
        '<script type="application/json" data-content-len="9" data-sjs>$relay</script>';
    expect(InstagramClient.productFromHtml(html)?['video_versions'], isNotEmpty);
    expect(InstagramClient.productFromHtml('<html>login</html>'), isNull);
  });

  test('instagram embed sidecar is read from contextJSON', () {
    final context = jsonEncode({
      'gql_data': {
        'shortcode_media': {
          '__typename': 'GraphSidecar',
          'owner': {'username': 'instagram'},
          'edge_sidecar_to_children': {
            'edges': [
              {
                'node': {'is_video': true, 'video_url': 'https://scontent.cdninstagram.com/a.mp4', 'display_url': 'https://scontent.cdninstagram.com/a.jpg'},
              },
              {
                'node': {'is_video': false, 'display_url': 'https://scontent.cdninstagram.com/b.jpg'},
              },
            ],
          },
        },
      },
    });
    final html = '<script>window.__x = {"contextJSON":${jsonEncode(context)}};</script>';
    final node = InstagramClient.shortcodeMediaFromEmbed(html);
    expect(node, isNotNull);
    final media = InstagramClient.fromShortcodeMedia(node!, code: 'c', pageUrl: 'https://www.instagram.com/p/c/');
    expect(media.options.single.photoUrls, [
      'https://scontent.cdninstagram.com/a.mp4',
      'https://scontent.cdninstagram.com/b.jpg',
    ]);
  });

  test('titles decode entities and drop trailing hashtags', () {
    expect(decodeHtmlEntities('&quot;Hi&quot; &#x201c;x&#x201d; &#064;me &#x1f638;'), '"Hi" \u201cx\u201d @me \u{1F638}');
    expect(cleanTitle('Typical orange cat 🐈 #cat #catlover #fyp ', fallback: 'TikTok'), 'Typical orange cat 🐈');
    expect(cleanTitle('#only #tags', fallback: 'TikTok'), '#only #tags');
    expect(cleanTitle('', fallback: 'TikTok'), 'TikTok');
    expect(cleanTitle('word ' * 40, fallback: 'x').length, lessThanOrEqualTo(101));
    expect(decodeEscaped(r'https:\u002F\u002Fv16m.tiktokcdn.com\u002Fa?b=1\u0026c=2'), 'https://v16m.tiktokcdn.com/a?b=1&c=2');
  });

  test('queue pumps oldest first after prepend', () {
    final store = LibraryStore();
    final newest = _item(id: 'new');
    final oldest = _item(id: 'old');
    final items = [newest, oldest];
    expect(store.nextQueued(items)?.id, 'old');
  });

  test('interrupted downloads go back to the queue', () {
    final store = LibraryStore();
    final recovered = store.recoverInterrupted([
      _item(id: 'a', status: LibraryItem.statusDownloading),
      _item(id: 'b', status: LibraryItem.statusDone),
    ]);
    expect(recovered.first.status, LibraryItem.statusQueued);
    expect(recovered.last.status, LibraryItem.statusDone);
  });

  test('paused jobs stay paused after a crash recover', () {
    final store = LibraryStore();
    final recovered = store.recoverInterrupted([
      _item(id: 'a', status: LibraryItem.statusPaused),
      _item(id: 'b', status: LibraryItem.statusDownloading),
    ]);
    expect(recovered.first.status, LibraryItem.statusPaused);
    expect(recovered.last.status, LibraryItem.statusQueued);
    expect(store.nextQueued(recovered)?.id, 'b');
  });

  test('lyrics names split artist and track', () {
    final names = LyricsClient.splitNames('Artist - Song (Official Video)', 'Artist Topic');
    expect(names.track.toLowerCase(), contains('song'));
    expect(names.artist, isNotEmpty);
  });

  test('song names come from the title, not the uploading channel', () {
    final rick = LyricsClient.splitNames(
      'Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)',
      'Rick Astley',
    );
    expect(rick.track, 'Never Gonna Give You Up');
    expect(rick.artist, 'Rick Astley');
    final label = LyricsClient.splitNames('Juice WRLD - Lucid Dreams (Official Audio)', 'Lyrical Lemonade');
    expect(label.artist, 'Juice WRLD');
    expect(label.track, 'Lucid Dreams');
    final vevo = LyricsClient.splitNames('Hello', 'AdeleVEVO');
    expect(vevo.artist, 'Adele');
    expect(vevo.track, 'Hello');
  });

  test('word-by-word lyric timings are dropped, line timings kept', () {
    const lrc = "[00:18.89] <00:18.89>We're <00:19.25>no <00:19.53>strangers\n"
        '[00:22.82]<00:22.82>You <00:23.23>know';
    expect(LyricsClient.lineSynced(lrc), "[00:18.89] We're no strangers\n[00:22.82]You know");
    expect(LyricsClient.lineSynced('  '), isNull);
  });

  test('plain lyrics are rebuilt from synced ones when missing', () async {
    final client = LyricsClient((uri) async => '{"syncedLyrics":"[ar:Rick]\\n[00:01.00]Line one\\n[00:02.50][00:09.00] <00:02.50>Line two","plainLyrics":null}');
    final hit = await client.find('Rick Astley - Song', null, null);
    expect(hit, isNotNull);
    expect(hit!.plain, 'Line one\nLine two');
    expect(hit.synced, contains('[00:02.50][00:09.00] Line two'));
  });
}
