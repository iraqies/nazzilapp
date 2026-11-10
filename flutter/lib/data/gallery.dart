import 'dart:io';

import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

import 'host.dart';

class GalleryService {
  static const album = 'Nazzil';

  Future<bool> ensureAccess({required bool images}) async {
    final granted = await Gal.requestAccess(toAlbum: true);
    if (granted) return true;
    if (Platform.isAndroid) {
      final permission = images ? Permission.photos : Permission.videos;
      final status = await permission.request();
      return status.isGranted || status.isLimited;
    }
    return false;
  }

  Future<void> saveFile(File file, {required bool image}) async {
    try {
      if (image) {
        await Gal.putImage(file.path, album: album);
      } else {
        await Gal.putVideo(file.path, album: album);
      }
    } catch (_) {
      // Keep the on-device copy even if the gallery insert fails.
    }
  }

  /// Photos and the video gallery refuse audio, so songs go to Music/Nazzil.
  Future<void> saveAudio(File file) async {
    if (!Platform.isAndroid) return;
    try {
      await DownloadHost.saveAudio(file.path);
    } catch (_) {}
  }
}
