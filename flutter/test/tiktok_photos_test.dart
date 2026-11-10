import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/data/clients/tiktok_client.dart';
import 'package:nazzil/data/link_parser.dart';
import 'package:nazzil/data/net.dart';
import 'package:nazzil/models/media.dart';

void main() {
  test('extracts supported links', () {
    expect(
      LinkParser.extract('watch this https://www.tiktok.com/@x/photo/1234567890123456789 wow'),
      'https://www.tiktok.com/@x/photo/1234567890123456789',
    );
    expect(LinkParser.isTikTokPhotoUrl('https://www.tiktok.com/@x/photo/1'), isTrue);
    expect(LinkParser.platformOf('https://vm.tiktok.com/abc'), PlatformId.tiktok);
  });

  test('tiktok photo payload becomes a photo album', () {
    final client = TikTokClient(NetClient());
    final media = client.parse({
      'id': '99',
      'title': 'album',
      'images': [
        'https://cdn.example/a.jpg',
        'https://cdn.example/b.jpg',
      ],
      'music': 'https://cdn.example/a.mp3',
      'author': {'nickname': 'z'},
    }, 'https://www.tiktok.com/@x/photo/99');
    expect(media.isPhotoAlbum, isTrue);
    expect(media.photos, hasLength(2));
    expect(media.options.first.kind, MediaKind.photo);
    final videos = media.options.where((o) => o.kind == MediaKind.video).toList();
    expect(videos, hasLength(1));
    expect(videos.single.photoUrls, media.photos);
    expect(videos.single.directUrl, isNull);
  });
}
