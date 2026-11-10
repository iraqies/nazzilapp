import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

import 'ffmpeg_args.dart';

class MediaConverter {
  Future<File> toMp3(File input, File output) =>
      _run(FfmpegArgs.mp3(input.path, output.path), output, 'Could not turn this into an MP3.');

  Future<File> join(File video, File audio, File output) =>
      _run(FfmpegArgs.join(video.path, audio.path, output.path), output, 'Could not put the video and sound together.');

  /// Hardware H.264 first; mpeg4 is built into every ffmpeg and plays on
  /// phones and computers alike. The post's sound is copied when MP4 takes
  /// it as is, otherwise re-encoded.
  Future<File> slideshow(List<File> images, File? audio, File output) async {
    final encoders = [
      if (Platform.isAndroid) 'h264_mediacodec',
      if (Platform.isIOS || Platform.isMacOS) 'h264_videotoolbox',
      'mpeg4',
    ];
    for (final encoder in encoders) {
      for (final audioCodec in audio == null ? const ['copy'] : const ['copy', 'aac']) {
        try {
          return await _run(
            FfmpegArgs.slideshow(
              images: [for (final image in images) image.path],
              audio: audio?.path,
              output: output.path,
              encoder: encoder,
              audioCodec: audioCodec,
            ),
            output,
            'Could not make the video.',
          );
        } on StateError {
          continue;
        }
      }
    }
    throw StateError('Could not make the video.');
  }

  Future<File> _run(List<String> args, File output, String failure) async {
    if (output.existsSync()) output.deleteSync();
    final session = await FFmpegKit.executeWithArguments(args);
    final code = await session.getReturnCode();
    if (ReturnCode.isSuccess(code) && output.existsSync() && output.lengthSync() > 1024) {
      return output;
    }
    if (output.existsSync()) output.deleteSync();
    throw StateError(failure);
  }
}
