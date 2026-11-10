import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/data/clients/reddit_client.dart';
import 'package:nazzil/data/clients/x_client.dart';
import 'package:nazzil/data/link_parser.dart';
import 'package:nazzil/data/net.dart';
import 'package:nazzil/models/media.dart';

const _mpd = '''
<MPD><Period>
<AdaptationSet contentType="video" maxHeight="1280">
<Representation bandwidth="214076" height="392" id="5" mimeType="video/mp4" width="220"><BaseURL>CMAF_220.mp4</BaseURL></Representation>
<Representation bandwidth="720172" height="640" id="7" mimeType="video/mp4" width="360"><BaseURL>CMAF_360.mp4</BaseURL></Representation>
<Representation bandwidth="2400000" height="1280" id="9" mimeType="video/mp4" width="720"><BaseURL>CMAF_720.mp4</BaseURL></Representation>
</AdaptationSet>
<AdaptationSet contentType="audio">
<Representation bandwidth="66000" id="1" mimeType="audio/mp4"><BaseURL>CMAF_AUDIO_64.mp4</BaseURL></Representation>
<Representation bandwidth="132000" id="2" mimeType="audio/mp4"><BaseURL>CMAF_AUDIO_128.mp4</BaseURL></Representation>
</AdaptationSet>
</Period></MPD>
''';

Map<String, dynamic> _listing(Map<String, dynamic> post) => {
      'kind': 'Listing',
      'data': {
        'children': [
          {'kind': 't3', 'data': post},
        ],
      },
    };

void main() {
  group('links', () {
    test('X and Reddit links are recognised by host, not by substring', () {
      expect(LinkParser.platformOf('https://x.com/a/status/1'), PlatformId.x);
      expect(LinkParser.platformOf('https://mobile.twitter.com/a/status/1'), PlatformId.x);
      expect(LinkParser.platformOf('https://www.reddit.com/r/a/comments/abc/t/'), PlatformId.reddit);
      expect(LinkParser.platformOf('https://v.redd.it/xyz'), PlatformId.reddit);
      expect(LinkParser.platformOf('https://dropbox.com/s/x'), PlatformId.unknown);
      expect(LinkParser.extract('look https://www.dropbox.com/x.com/thing'), 'https://www.dropbox.com/x.com/thing');
      expect(LinkParser.extract('see x.com/nasa/status/123?s=20 now'), 'https://x.com/nasa/status/123?s=20');
    });

    test('ids and duplicate keys', () {
      expect(LinkParser.tweetId('https://twitter.com/i/web/status/1584807233024794624'), '1584807233024794624');
      expect(LinkParser.redditId('https://old.reddit.com/r/pics/comments/1XNB2YS/title/'), '1xnb2ys');
      expect(LinkParser.redditId('https://redd.it/1xn6m2q'), '1xn6m2q');
      expect(LinkParser.identityKey('https://x.com/a/status/42'), 'x:42');
      expect(LinkParser.identityKey('https://www.reddit.com/comments/abc12'), 'rd:abc12');
    });

    test('long titles never cut a character in half', () {
      final title = '${'a' * 59}𒀂𒀂';
      final name = LinkParser.sanitizeFilename(title);
      expect(name, 'a' * 59);
      expect(name.runes.contains(0xFFFD), isFalse);
      final clipped = cleanTitle('${'b' * 99}𒀂 tail', fallback: 'x');
      expect(clipped.codeUnits.any((u) => u >= 0xD800 && u <= 0xDFFF), isFalse);
    });
  });

  group('reddit', () {
    final video = {
      'id': '1xo9swr',
      'title': 'Best WALL-E cosplay ever',
      'author': 'someone',
      'secure_media': {
        'reddit_video': {
          'fallback_url': 'https://v.redd.it/eqs6/CMAF_720.mp4?source=fallback',
          'dash_url': 'https://v.redd.it/eqs6/DASHPlaylist.mpd',
          'has_audio': true,
          'height': 1280,
          'duration': 43,
        },
      },
    };

    test('video qualities come from the DASH manifest with the best audio joined', () {
      final info = RedditClient.parse(video, pageUrl: 'https://www.reddit.com/comments/1xo9swr', manifest: _mpd);
      expect(info.platform, PlatformId.reddit);
      expect(info.author, 'u/someone');
      expect(info.duration, 43);
      final hd = info.options.firstWhere((o) => o.id == 'rd-hd');
      expect(hd.directUrl, 'https://v.redd.it/eqs6/CMAF_720.mp4');
      expect(hd.audioUrl, 'https://v.redd.it/eqs6/CMAF_AUDIO_128.mp4');
      expect(info.options.firstWhere((o) => o.id == 'rd-sd').directUrl, 'https://v.redd.it/eqs6/CMAF_360.mp4');
      expect(info.options.firstWhere((o) => o.id == 'rd-audio').kind, MediaKind.audio);
    });

    test('without a manifest the fallback file is used with the probed audio', () {
      final info = RedditClient.parse(video, pageUrl: 'p', audioGuess: 'https://v.redd.it/eqs6/DASH_audio.mp4');
      expect(info.options.map((o) => o.id), ['rd-hd', 'rd-audio']);
      expect(info.options.first.directUrl, 'https://v.redd.it/eqs6/CMAF_720.mp4?source=fallback');
      expect(info.options.first.audioUrl, 'https://v.redd.it/eqs6/DASH_audio.mp4');
    });

    test('galleries keep their order and use the original files', () {
      final post = RedditClient.postFrom([
        _listing({
          'id': 'g1',
          'title': 'Gallery',
          'is_gallery': true,
          'gallery_data': {
            'items': [
              {'media_id': 'bbb'},
              {'media_id': 'aaa'},
              {'media_id': 'ccc'},
            ],
          },
          'media_metadata': {
            'aaa': {'status': 'valid', 'e': 'Image', 'm': 'image/png', 's': {'u': 'https://preview.redd.it/aaa.png?width=10'}},
            'bbb': {'status': 'valid', 'e': 'Image', 'm': 'image/jpg', 's': {'u': 'https://preview.redd.it/bbb.jpg?width=10'}},
            'ccc': {'status': 'valid', 'e': 'Image', 'm': 'image/jpeg', 's': {'u': 'https://preview.redd.it/ccc.jpeg?width=4000&format=pjpg'}},
          },
        }),
      ])!;
      final info = RedditClient.parse(post, pageUrl: 'p');
      expect(info.photos, ['https://i.redd.it/bbb.jpg', 'https://i.redd.it/aaa.png', 'https://i.redd.it/ccc.jpeg']);
      expect(info.options.map((o) => o.id), ['rd-photos', 'rd-slideshow']);
    });

    test('a crosspost without media reads the original post', () {
      final post = RedditClient.postFrom([
        _listing({
          'id': 'cross',
          'title': 'Crosspost',
          'crosspost_parent_list': [video],
        }),
      ])!;
      expect(post['id'], '1xo9swr');
    });

    test('gifs offer the mp4 and the gif file', () {
      final info = RedditClient.parse({
        'id': 'gif1',
        'title': 'Toyota AE86',
        'post_hint': 'image',
        'url': 'https://i.redd.it/7qus.gif',
        'preview': {
          'images': [
            {
              'source': {'url': 'https://preview.redd.it/7qus.gif?s=1'},
              'variants': {
                'mp4': {
                  'source': {'url': 'https://preview.redd.it/7qus.gif?format=mp4&s=2'},
                },
              },
            },
          ],
        },
      }, pageUrl: 'p');
      expect(info.options.map((o) => o.label), ['GIF', 'GIF file']);
      expect(info.options.first.directUrl, 'https://preview.redd.it/7qus.gif?format=mp4&s=2');
    });

    test('text posts explain there is nothing to save', () {
      expect(() => RedditClient.parse({'id': 't', 'title': 'Just text', 'is_self': true}, pageUrl: 'p'), throwsStateError);
    });
  });

  group('x', () {
    test('a video post offers HD, SD and audio, best bitrate first', () {
      final info = XClient.parseEmbed({
        '__typename': 'Tweet',
        'id_str': '2023205364368351634',
        'text': 'Look at this https://t.co/5xrYfslWJc',
        'user': {'name': 'duck', 'screen_name': 'ExtremeBlitz__'},
        'mediaDetails': [
          {
            'type': 'video',
            'media_url_https': 'https://pbs.twimg.com/amplify_video_thumb/1/img/a.jpg',
            'video_info': {
              'duration_millis': 9516,
              'variants': [
                {'content_type': 'application/x-mpegURL', 'url': 'https://video.twimg.com/a/pl/x.m3u8'},
                {'bitrate': 256000, 'content_type': 'video/mp4', 'url': 'https://video.twimg.com/a/vid/avc1/566x270/s.mp4'},
                {'bitrate': 2176000, 'content_type': 'video/mp4', 'url': 'https://video.twimg.com/a/vid/avc1/1080x514/h.mp4'},
                {'bitrate': 832000, 'content_type': 'video/mp4', 'url': 'https://video.twimg.com/a/vid/avc1/756x360/m.mp4'},
              ],
            },
          },
        ],
      }, pageUrl: 'https://x.com/ExtremeBlitz__/status/2023205364368351634');
      expect(info.platform, PlatformId.x);
      expect(info.title, 'Look at this');
      expect(info.duration, 10);
      expect(info.options.map((o) => o.id), ['x-hd', 'x-sd', 'x-audio']);
      expect(info.options[0].directUrl, endsWith('1080x514/h.mp4'));
      expect(info.options[0].height, 514);
      expect(info.options[1].directUrl, endsWith('756x360/m.mp4'));
    });

    test('photo posts get the original size and a slideshow when there are several', () {
      final info = XClient.parseEmbed({
        '__typename': 'Tweet',
        'id_str': '1',
        'text': '',
        'user': {'screen_name': 'nasa'},
        'mediaDetails': [
          {'type': 'photo', 'media_url_https': 'https://pbs.twimg.com/media/A.jpg'},
          {'type': 'photo', 'media_url_https': 'https://pbs.twimg.com/media/B.png'},
        ],
      }, pageUrl: 'https://x.com/nasa/status/1');
      expect(info.title, 'X post by @nasa');
      expect(info.photos, [
        'https://pbs.twimg.com/media/A?format=jpg&name=orig',
        'https://pbs.twimg.com/media/B?format=png&name=orig',
      ]);
      expect(info.options.map((o) => o.id), ['x-photos', 'x-slideshow']);
    });

    test('gifs are one silent video and fxtwitter is understood too', () {
      final info = XClient.parseFx({
        'id': '9',
        'text': 'gif',
        'author': {'name': 'A', 'screen_name': 'a'},
        'media': {
          'all': [
            {
              'type': 'gif',
              'url': 'https://video.twimg.com/tweet_video/G.mp4',
              'thumbnail_url': 'https://pbs.twimg.com/tweet_video_thumb/G.jpg',
            },
          ],
        },
      }, pageUrl: 'https://x.com/a/status/9');
      expect(info.options.single.label, 'GIF');
      expect(info.options.single.directUrl, 'https://video.twimg.com/tweet_video/G.mp4');
    });

    test('a quote without media of its own uses the quoted post', () {
      final info = XClient.parseEmbed({
        '__typename': 'Tweet',
        'id_str': '5',
        'text': 'so true',
        'user': {'screen_name': 'b'},
        'quoted_tweet': {
          'id_str': '4',
          'text': 'original',
          'user': {'screen_name': 'c'},
          'mediaDetails': [
            {'type': 'photo', 'media_url_https': 'https://pbs.twimg.com/media/Q.jpg'},
          ],
        },
      }, pageUrl: 'https://x.com/b/status/5');
      expect(info.title, 'original');
      expect(info.options.single.id, 'x-photos');
    });
  });
}
