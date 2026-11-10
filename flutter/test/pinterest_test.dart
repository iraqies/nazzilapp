import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/data/clients/pinterest_client.dart';
import 'package:nazzil/data/link_parser.dart';
import 'package:nazzil/models/media.dart';

const _master = '''#EXTM3U
#EXT-X-VERSION:6
#EXT-X-INDEPENDENT-SEGMENTS

#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio1",NAME="1",AUTOSELECT=YES,URI="abc_audio.m3u8",CHANNELS="2"
#EXT-X-STREAM-INF:BANDWIDTH=345264,CODECS="avc1.64080D,mp4a.40.29",RESOLUTION=234x416,AUDIO="audio1"
abc_240w.m3u8

#EXT-X-STREAM-INF:BANDWIDTH=535056,CODECS="avc1.64081E,mp4a.40.29",RESOLUTION=360x640,AUDIO="audio1"
abc_360w.m3u8

#EXT-X-STREAM-INF:BANDWIDTH=930720,CODECS="avc1.64081F,mp4a.40.29",RESOLUTION=576x1024,AUDIO="audio1"
abc_720w.m3u8
''';

const _media = '''#EXTM3U
#EXT-X-TARGETDURATION:2
#EXT-X-VERSION:6
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-MAP:URI="abc_720w.cmfv",BYTERANGE="1031@0"
#EXTINF:2
#EXT-X-BYTERANGE:93839@1239
abc_720w.cmfv
#EXTINF:2
#EXT-X-BYTERANGE:186733@95078
abc_720w.cmfv
#EXT-X-ENDLIST
''';

void main() {
  group('links', () {
    test('pin ids from every link shape', () {
      expect(LinkParser.pinId('https://www.pinterest.com/pin/472244710955342084/'), '472244710955342084');
      expect(LinkParser.pinId('https://www.pinterest.com/pin/skillet-chicken-and-ravioli-video--255016397643256616/'), '255016397643256616');
      expect(LinkParser.pinId('https://pinterest.co.uk/pin/123456789/sent/?invite_code=x'), '123456789');
      expect(LinkParser.pinId('https://de.pinterest.com/pin/987654321'), '987654321');
      expect(LinkParser.pinId('https://www.pinterest.com/sallysbakeblog/videos/'), isNull);
      expect(LinkParser.identityKey('https://www.pinterest.com/pin/472244710955342084/'), 'pin:472244710955342084');
    });

    test('hosts decide the platform, not words in the path', () {
      expect(LinkParser.platformOf('https://pin.it/4fQyEuL3m'), PlatformId.pinterest);
      expect(LinkParser.platformOf('https://www.pinterest.com.au/pin/1234567/'), PlatformId.pinterest);
      expect(LinkParser.platformOf('https://www.pinterest.com/pin/youtube-tiktok-ideas--1234567/'), PlatformId.pinterest);
      expect(LinkParser.platformOf('https://www.reddit.com/r/youtube/comments/abc/t/'), PlatformId.reddit);
      expect(LinkParser.platformOf('https://notpinterest.com/pin/1234567'), PlatformId.unknown);
      expect(LinkParser.extract('look pin.it/4fQyEuL3m'), 'https://pin.it/4fQyEuL3m');
    });
  });

  group('hls', () {
    test('master playlist gives variants best first and the audio track', () {
      final master = PinterestClient.readMaster(_master, 'https://v1.pinimg.com/videos/iht/hls/ab/abc.m3u8')!;
      expect(master.audio, 'https://v1.pinimg.com/videos/iht/hls/ab/abc_audio.m3u8');
      expect(master.variants.map((v) => v.$2), [1024, 640, 416]);
      expect(master.variants.first.$1, 'https://v1.pinimg.com/videos/iht/hls/ab/abc_720w.m3u8');
    });

    test('byte-range playlists collapse to their single CMAF file', () {
      expect(PinterestClient.mapUri(_media, 'https://v1.pinimg.com/hls/abc_720w.m3u8'), 'https://v1.pinimg.com/hls/abc_720w.cmfv');
      const segmented = '#EXTM3U\n#EXT-X-MAP:URI="init.mp4"\n#EXTINF:2\nseg1.m4s\n#EXTINF:2\nseg2.m4s\n';
      expect(PinterestClient.mapUri(segmented, 'https://x/a.m3u8'), isNull);
      expect(PinterestClient.mapUri('#EXTM3U\n#EXTINF:2\na.ts\n', 'https://x/a.m3u8'), isNull);
    });
  });

  group('pins', () {
    test('a video pin with a direct mp4', () {
      final pin = <String, dynamic>{
        'title': '',
        'description': 'Apple of Your Eyes Makeup Warmer',
        'pinner': {'full_name': 'Ana'},
        'images': {
          'orig': {'url': 'https://i.pinimg.com/originals/e2/a.jpg'},
        },
        'videos': {
          'video_list': {
            'V_720P': {'url': 'https://v1.pinimg.com/videos/iht/720p/54/a.mp4', 'height': 1280, 'duration': 38567.0},
            'V_HLSV4': {'url': 'https://v1.pinimg.com/videos/iht/hls/54/a.m3u8', 'height': 1280},
          },
        },
      };
      final items = PinterestClient.itemsOf(pin);
      final info = PinterestClient.build(pin, items, pageUrl: 'p', id: '1');
      expect(info.platform, PlatformId.pinterest);
      expect(info.title, 'Apple of Your Eyes Makeup Warmer');
      expect(info.author, 'Ana');
      expect(info.duration, 39);
      expect(info.thumbnail, 'https://i.pinimg.com/originals/e2/a.jpg');
      expect(info.options.map((o) => o.id), ['pin-hd', 'pin-audio']);
      expect(info.options.first.directUrl, 'https://v1.pinimg.com/videos/iht/720p/54/a.mp4');
      expect(info.options.first.audioUrl, isNull);
    });

    test('an HLS-only pin joins CMAF video and audio', () {
      const items = [
        PinItem(
          image: 'https://i.pinimg.com/t.jpg',
          videos: [('https://v1.pinimg.com/a_720w.cmfv', 1024), ('https://v1.pinimg.com/a_360w.cmfv', 640), ('https://v1.pinimg.com/a_240w.cmfv', 416)],
          audio: 'https://v1.pinimg.com/a_audio.cmfa',
        ),
      ];
      final info = PinterestClient.build(const {'grid_title': 'Cat'}, items, pageUrl: 'p', id: '1');
      expect(info.options.map((o) => o.id), ['pin-hd', 'pin-sd', 'pin-audio']);
      expect(info.options[0].audioUrl, 'https://v1.pinimg.com/a_audio.cmfa');
      expect(info.options[1].height, 640);
      expect(info.options[1].audioUrl, 'https://v1.pinimg.com/a_audio.cmfa');
      expect(info.options[2].directUrl, 'https://v1.pinimg.com/a_audio.cmfa');
      expect(info.options[2].ext, 'm4a');
    });

    test('idea pins with several pages become an album', () {
      final pin = <String, dynamic>{
        'title': 'Classic Cheesecake Recipe',
        'native_creator': {'full_name': "Sally's Baking"},
        'images': {
          'orig': {'url': 'https://i.pinimg.com/originals/d9/cover.jpg'},
        },
        'story_pin_data': {
          'pages': [
            {
              'blocks': [
                {
                  'image': {
                    'images': {
                      'originals': {'url': 'https://i.pinimg.com/originals/1.jpg', 'width': 1000},
                    },
                  },
                },
              ],
            },
            {
              'blocks': [
                {
                  'video': {
                    'video_list': {
                      'V_EXP4': {'url': 'https://v1.pinimg.com/videos/mc/expMp4/b_t4.mp4', 'height': 640},
                      'V_EXP7': {'url': 'https://v1.pinimg.com/videos/mc/expMp4/b_t7.mp4', 'height': 1920},
                    },
                  },
                },
              ],
            },
          ],
        },
      };
      final info = PinterestClient.build(pin, PinterestClient.itemsOf(pin), pageUrl: 'p', id: '1');
      expect(info.options.single.id, 'pin-photos');
      expect(info.options.single.label, 'Album');
      expect(info.options.single.photoUrls, ['https://i.pinimg.com/originals/1.jpg', 'https://v1.pinimg.com/videos/mc/expMp4/b_t7.mp4']);
    });

    test('a single image pin, and a GIF pin', () {
      final image = <String, dynamic>{
        'title': 'Kitchen',
        'images': {
          '236x': {'url': 'https://i.pinimg.com/236x/a.jpg', 'width': 236},
          'orig': {'url': 'https://i.pinimg.com/originals/a.jpg', 'width': 2000},
        },
      };
      final info = PinterestClient.build(image, PinterestClient.itemsOf(image), pageUrl: 'p', id: '1');
      expect(info.photos, ['https://i.pinimg.com/originals/a.jpg']);
      expect(info.options.map((o) => o.id), ['pin-photos']);

      final gif = <String, dynamic>{
        'images': {
          'orig': {'url': 'https://i.pinimg.com/originals/b.gif'},
        },
        'pinner': {'full_name': 'Bo'},
      };
      final gifInfo = PinterestClient.build(gif, PinterestClient.itemsOf(gif), pageUrl: 'p', id: '1');
      expect(gifInfo.title, 'Pin by Bo');
      expect(gifInfo.options.single.label, 'GIF');
      expect(gifInfo.options.single.ext, 'gif');
    });
  });
}
