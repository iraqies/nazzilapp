import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nazzil/data/ffmpeg_args.dart';
import 'package:nazzil/data/net.dart';
import 'package:nazzil/models/media.dart';

void main() {
  test('mp3 command keeps only the first audio stream at 320 kbps', () {
    final args = FfmpegArgs.mp3('in.webm', 'out.mp3');
    expect(args, containsAllInOrder(['-i', 'in.webm', '-map', '0:a:0', '-vn']));
    expect(args, containsAllInOrder(['-c:a', 'libmp3lame', '-b:a', '320k']));
    expect(args.last, 'out.mp3');
  });

  test('join command copies video and sound without re-encoding', () {
    final args = FfmpegArgs.join('v.mp4', 'a.m4a', 'out.mp4');
    expect(args, containsAllInOrder(['-map', '0:v:0', '-map', '1:a:0', '-c', 'copy']));
    expect(args.last, 'out.mp4');
  });

  test('slideshow shows every photo and loops the sound to the end', () {
    final args = FfmpegArgs.slideshow(
      images: ['1.jpg', '2.jpg', '3.webp', '4.jpg'],
      audio: 'sound',
      output: 'out.mp4',
      encoder: 'h264_mediacodec',
    );
    expect(args.where((a) => a == '-loop').length, 4);
    expect(args, containsAllInOrder(['-stream_loop', '-1', '-i', 'sound']));
    expect(args.firstWhere((a) => a.contains('concat=')), contains('concat=n=4:v=1:a=0[v]'));
    expect(args, containsAllInOrder(['-map', '4:a:0', '-c:a', 'copy']));
    expect(args, containsAllInOrder(['-t', '12']));
    final silent = FfmpegArgs.slideshow(images: ['1.jpg'], output: 'o.mp4', encoder: 'mpeg4');
    expect(silent, isNot(contains('-stream_loop')));
    expect(silent, containsAllInOrder(['-q:v', '2']));
    expect(FfmpegArgs.slideSeconds(1), 10);
    expect(FfmpegArgs.slideSeconds(2), 5);
    expect(FfmpegArgs.slideSeconds(9), 3);
  });

  test('mp3 sniffing accepts ID3 and frame sync, rejects MP4', () {
    final dir = Directory.systemTemp.createTempSync('nazzil-mp3');
    File write(String name, List<int> bytes) => File('${dir.path}/$name')..writeAsBytesSync(bytes);
    expect(FfmpegArgs.isMp3(write('a.mp3', [0x49, 0x44, 0x33, 3, 0])), isTrue);
    expect(FfmpegArgs.isMp3(write('b.mp3', [0xFF, 0xFB, 0x90, 0x64])), isTrue);
    expect(FfmpegArgs.isMp3(write('c.mp3', [0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70])), isFalse);
    expect(FfmpegArgs.isMp3(write('d.aac', [0xFF, 0xF1, 0x50, 0x80])), isFalse);
    dir.deleteSync(recursive: true);
  });

  test('youtube files are fetched in ranges and the total comes from Content-Range', () {
    expect(NetClient.isThrottledHost('https://rr2---sn-p5qlsnd6.googlevideo.com/videoplayback?x=1'), isTrue);
    expect(NetClient.isThrottledHost('https://v16.tiktokcdn.com/a.mp4'), isFalse);
    expect(NetClient.totalFromContentRange('bytes 0-10485759/80932101'), 80932101);
    expect(NetClient.totalFromContentRange(null), isNull);
  });

  test('joined options survive a save and restore', () {
    const option = QualityOption(
      id: 'yt-hd-1080',
      label: 'HD',
      ext: 'mp4',
      kind: MediaKind.video,
      height: 1080,
      directUrl: 'https://v.example/video',
      audioUrl: 'https://v.example/audio',
    );
    final back = QualityOption.fromJson(option.toJson());
    expect(back.audioUrl, 'https://v.example/audio');
    expect(back.height, 1080);
  });
}
