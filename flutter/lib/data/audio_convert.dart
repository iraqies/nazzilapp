import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

class AudioConverter {
  /// Tags are written afterwards by [DownloadHost.tagAudio], so the source's
  /// own metadata (YouTube titles, encoder names) is dropped here.
  static List<String> mp3Args(String input, String output) => [
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

  Future<File> toMp3(File input, File output) async {
    if (output.existsSync()) output.deleteSync();
    final session = await FFmpegKit.executeWithArguments(mp3Args(input.path, output.path));
    final code = await session.getReturnCode();
    if (ReturnCode.isSuccess(code) && output.existsSync() && output.lengthSync() > 1024) {
      return output;
    }
    if (output.existsSync()) output.deleteSync();
    throw StateError('Could not turn this into an MP3.');
  }
}
