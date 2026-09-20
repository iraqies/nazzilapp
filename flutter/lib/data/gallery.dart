import 'dart:io';

import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

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
}
