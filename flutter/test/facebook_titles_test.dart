import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/data/clients/facebook_client.dart';
import 'package:nazzil/data/clients/tiktok_client.dart';

void main() {
  test('facebook titles drop view counts and keep the page as author', () {
    final parts = FacebookClient.titleParts(
      null,
      '19M views &#xb7; 690K reactions | Padre ense&#xf1;a a su hijo | InfoPico',
    );
    expect(parts?.title, 'Padre enseña a su hijo');
    expect(parts?.author, 'InfoPico');
    expect(FacebookClient.titleParts('Facebook', null), isNull);
  });

  test('facebook video ids come from watch, videos and reel links', () {
    expect(FacebookClient.videoIdOf('https://www.facebook.com/watch/?v=647537299265662'), '647537299265662');
    expect(FacebookClient.videoIdOf('https://www.facebook.com/cnn/videos/10155529876156509/'), '10155529876156509');
    expect(FacebookClient.videoIdOf('https://www.facebook.com/reel/647537299265662/'), '647537299265662');
  });

  test('facebook poster prefers the embed jpg', () {
    const html = '<img src="https://scontent-iad3-1.xx.fbcdn.net/v/t15.13418-10/1_n.jpg?stp=dst-jpg&amp;_nc=1">';
    expect(FacebookClient.jpegPoster(html), 'https://scontent-iad3-1.xx.fbcdn.net/v/t15.13418-10/1_n.jpg?stp=dst-jpg&_nc=1');
  });

  test('a tiktok page only counts when it is the post itself', () {
    expect(TikTokClient.pageIsPost('{"itemStruct":{"id":"7704761660816313622"}}', '7704761660816313622'), isTrue);
    expect(TikTokClient.pageIsPost('{"itemList":[{"id":"7111111111111111111"}]}', '7704761660816313622'), isFalse);
  });
}
