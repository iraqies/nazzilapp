import 'dart:math';
import 'dart:io';

/// Kept free of Flutter imports so the commands can be checked against a
/// desktop ffmpeg in tests.
class FfmpegArgs {
  /// Tags are written afterwards by [DownloadHost.tagAudio], so the source's
  /// own metadata (YouTube titles, encoder names) is dropped here.
  static List<String> mp3(String input, String output, {String? title, String? artist}) => [
        '-y',
        '-hide_banner',
        '-nostdin',
        '-i',
        input,
        '-map',
        '0:a:0',
        '-vn',
        '-map_metadata',
        '-1',
        if (title != null && title.isNotEmpty) ...['-metadata', 'title=$title'],
        if (artist != null && artist.isNotEmpty) ...['-metadata', 'artist=$artist'],
        '-c:a',
        'libmp3lame',
        '-b:a',
        '320k',
        '-ar',
        '44100',
        '-id3v2_version',
        '3',
        output,
      ];

  /// `-c copy` only works when the streams already fit MP4 (H.264 + AAC).
  static List<String> join(String video, String audio, String output) => [
        '-y',
        '-hide_banner',
        '-nostdin',
        '-i',
        video,
        '-i',
        audio,
        '-map',
        '0:v:0',
        '-map',
        '1:a:0',
        '-c',
        'copy',
        '-movflags',
        '+faststart',
        output,
      ];

  /// At least 3 seconds a photo, and at least 10 seconds in all so a single
  /// photo with music is still worth watching.
  static int slideSeconds(int photos) => photos <= 0 ? 3 : max(3, (10 / photos).ceil());

  /// Each photo is letterboxed onto a 1080x1920 frame for [slideSeconds];
  /// the post's sound loops until the last photo ends.
  static List<String> slideshow({
    required List<String> images,
    String? audio,
    required String output,
    required String encoder,
    String audioCodec = 'copy',
  }) {
    const w = 1080, h = 1920, fps = 30;
    final seconds = slideSeconds(images.length);
    final args = <String>['-y', '-hide_banner', '-nostdin'];
    for (final image in images) {
      args.addAll(['-loop', '1', '-framerate', '$fps', '-t', '$seconds', '-i', image]);
    }
    if (audio != null) args.addAll(['-stream_loop', '-1', '-i', audio]);
    final chains = [
      for (var i = 0; i < images.length; i++)
        '[$i:v]scale=$w:$h:force_original_aspect_ratio=decrease,'
            'pad=$w:$h:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps=$fps,format=yuv420p[v$i]',
    ];
    final joined = '${[for (var i = 0; i < images.length; i++) '[v$i]'].join()}concat=n=${images.length}:v=1:a=0[v]';
    args.addAll(['-filter_complex', '${chains.join(';')};$joined', '-map', '[v]']);
    if (audio != null) args.addAll(['-map', '${images.length}:a:0', '-c:a', audioCodec]);
    args.addAll([
      '-c:v',
      encoder,
      if (encoder == 'mpeg4') ...['-q:v', '2'] else ...['-b:v', '8M'],
      '-pix_fmt',
      'yuv420p',
      '-t',
      '${images.length * seconds}',
      '-movflags',
      '+faststart',
      output,
    ]);
    return args;
  }

  static bool isMp3(File file) {
    try {
      final raf = file.openSync();
      final head = raf.readSync(3);
      raf.closeSync();
      if (head.length < 3) return false;
      if (head[0] == 0x49 && head[1] == 0x44 && head[2] == 0x33) return true;
      return head[0] == 0xFF && (head[1] & 0xE6) == 0xE2;
    } catch (_) {
      return false;
    }
  }
}
