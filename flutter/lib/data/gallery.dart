import 'dart:io';

import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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

  /// Photos and the video gallery refuse audio, so songs go to Music/Nazzil
  /// on Android and to the app's Documents/Nazzil folder (shown in the Files
  /// app) on iOS.
  Future<void> saveAudio(File file) async {
    try {
      if (Platform.isAndroid) {
        await DownloadHost.saveAudio(file.path);
      } else if (Platform.isIOS) {
        final folder = Directory(p.join((await getApplicationDocumentsDirectory()).path, album));
        await folder.create(recursive: true);
        await file.copy(_free(folder, p.basename(file.path)).path);
      }
    } catch (_) {}
  }

  File _free(Directory folder, String name) {
    var target = File(p.join(folder.path, name));
    var index = 1;
    while (target.existsSync()) {
      target = File(p.join(folder.path, '${p.basenameWithoutExtension(name)} ($index)${p.extension(name)}'));
      index += 1;
    }
    return target;
  }
}
