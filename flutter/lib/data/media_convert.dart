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
    final attempts = <(String, int)>[
      if (Platform.isAndroid) ...[('h264_mediacodec', 1080), ('h264_mediacodec', 720)],
      if (Platform.isIOS || Platform.isMacOS) ...[('h264_videotoolbox', 1080), ('h264_videotoolbox', 720)],
      ('mpeg4', 1080),
    ];
    for (final (encoder, width) in attempts) {
      for (final audioCodec in audio == null ? const ['aac'] : const ['aac', 'copy']) {
        try {
          return await _run(
            FfmpegArgs.slideshow(
              images: [for (final image in images) image.path],
              audio: audio?.path,
              output: output.path,
              encoder: encoder,
              audioCodec: audioCodec,
              width: width,
            ),
            output,
            'Could not make the video.',
            needsVideo: true,
          );
        } on _NoPicture {
          break;
        } on StateError {
          continue;
        }
      }
    }
    throw StateError('Could not make the video.');
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
    throw ok ? _NoPicture(failure) : StateError(failure);
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

/// The encoder ran but delivered no frames; another sound codec will not help.
class _NoPicture extends StateError {
  _NoPicture(super.message);
}
