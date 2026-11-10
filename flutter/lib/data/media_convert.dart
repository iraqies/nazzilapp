import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

import 'ffmpeg_args.dart';

class MediaConverter {
  Future<File> toMp3(File input, File output) =>
      _run(FfmpegArgs.mp3(input.path, output.path), output, 'Could not turn this into an MP3.');

  Future<File> join(File video, File audio, File output) =>
      _run(FfmpegArgs.join(video.path, audio.path, output.path), output, 'Could not put the video and sound together.');

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
