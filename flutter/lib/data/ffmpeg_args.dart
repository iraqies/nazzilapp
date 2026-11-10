import 'dart:io';

/// Kept free of Flutter imports so the commands can be checked against a
/// desktop ffmpeg in tests.
class FfmpegArgs {
  /// Tags are written afterwards by [DownloadHost.tagAudio], so the source's
  /// own metadata (YouTube titles, encoder names) is dropped here.
  static List<String> mp3(String input, String output) => [
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
