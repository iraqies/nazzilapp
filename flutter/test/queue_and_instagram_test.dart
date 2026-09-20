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

void main() {
  test('instagram photo carousel stays photos even if a video url is present', () {
    final media = InstagramClient(NetClient()).metaFrom(
      videos: ['https://cdninstagram.com/a.mp4'],
      photos: [
        'https://scontent.cdninstagram.com/1.jpg',
        'https://scontent.cdninstagram.com/2.jpg',
      ],
    );
    expect(media.isPhotoAlbum, isTrue);
    expect(media.options.first.kind, MediaKind.photo);
    expect(media.options.any((o) => o.kind == MediaKind.video), isFalse);
  });

  test('instagram single photo without video is photos, reel without album is video', () {
    final photos = InstagramClient(NetClient()).metaFrom(
      videos: const [],
      photos: ['https://scontent.cdninstagram.com/1.jpg'],
    );
    expect(photos.options.first.kind, MediaKind.photo);

    final reel = InstagramClient(NetClient()).metaFrom(
      videos: ['https://cdninstagram.com/a.mp4'],
      photos: ['https://scontent.cdninstagram.com/thumb.jpg'],
    );
    expect(reel.options.first.kind, MediaKind.video);
    expect(reel.photos, isEmpty);
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
}
