import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:flutter/foundation.dart';

import 'ffmpeg_args.dart';

class MediaConverter {
  Future<File> toMp3(File input, File output, {String? title, String? artist}) => _run(
        FfmpegArgs.mp3(input.path, output.path, title: title, artist: artist),
        output,
        'Could not turn this into an MP3.',
      );

  Future<File> join(File video, File audio, File output) =>
      _run(FfmpegArgs.join(video.path, audio.path, output.path), output, 'Could not put the video and sound together.');

  /// Hardware H.264 first, at 720p too because some encoders (the software
  /// one on slow devices) refuse 1080x1920 by encoding nothing; mpeg4 is
  /// built into every ffmpeg. AAC sound plays everywhere, a copy is the
  /// fallback.
  Future<File> slideshow(List<File> images, File? audio, File output) async {
    const failure = 'Could not make the video.';
    final paths = [for (final image in images) image.path];
    final seconds = images.length * FfmpegArgs.slideSeconds(images.length);
    final sounds = audio == null ? const ['aac'] : const ['aac', 'copy'];
    final hardware = Platform.isAndroid
        ? 'h264_mediacodec'
        : (Platform.isIOS || Platform.isMacOS)
            ? 'h264_videotoolbox'
            : null;
    if (hardware != null) {
      final raw = File('${output.path}.h264');
      try {
        for (final width in const [1080, 720]) {
          try {
            await _run(FfmpegArgs.slideshow(images: paths, output: raw.path, encoder: hardware, width: width), raw, failure);
          } on StateError {
            continue;
          }
          for (final sound in sounds) {
            try {
              return await _run(
                FfmpegArgs.wrapH264(video: raw.path, audio: audio?.path, output: output.path, seconds: seconds, audioCodec: sound),
                output,
                failure,
                needsVideo: true,
              );
            } on StateError {
              continue;
            }
          }
        }
      } finally {
        if (raw.existsSync()) raw.deleteSync();
      }
    }
    for (final sound in sounds) {
      try {
        return await _run(
          FfmpegArgs.slideshow(images: paths, audio: audio?.path, output: output.path, encoder: 'mpeg4', audioCodec: sound),
          output,
          failure,
          needsVideo: true,
        );
      } on StateError {
        continue;
      }
    }
    throw StateError(failure);
  }

  Future<File> _run(List<String> args, File output, String failure, {bool needsVideo = false}) async {
    if (output.existsSync()) output.deleteSync();
    final session = await FFmpegKit.executeWithArguments(args);
    final code = await session.getReturnCode();
    final ok = ReturnCode.isSuccess(code) && output.existsSync() && output.lengthSync() > 1024;
    // A hardware encoder that never delivers a frame still exits 0, leaving
    // an MP4 with only the sound in it.
    if (ok && (!needsVideo || await _hasVideo(output))) return output;
    final logs = await session.getAllLogsAsString() ?? '';
    debugPrint('ffmpeg ${ok ? 'wrote no video' : 'failed ($code)'}: '
        '${logs.length > 3000 ? logs.substring(logs.length - 3000) : logs}');
    if (output.existsSync()) output.deleteSync();
    throw StateError(failure);
  }

  static Future<bool> _hasVideo(File file) async {
    try {
      final session = await FFprobeKit.getMediaInformation(file.path);
      final streams = session.getMediaInformation()?.getStreams() ?? const [];
      return streams.any((s) => s.getType() == 'video');
    } catch (_) {
      return false;
    }
  }
}
