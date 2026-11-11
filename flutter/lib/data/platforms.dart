import 'dart:io';

import 'package:flutter/foundation.dart';

abstract final class Platforms {
  /// What this process runs on. Android and iOS have the native host
  /// (notifications, share sheet, tagging, gallery); desktops do this in Dart.
  static bool get mobile => Platform.isAndroid || Platform.isIOS;

  // What the screens are drawn for follows Flutter's target platform: the
  // system itself on a device, and a phone in tests unless a test says otherwise.

  static bool get desktop => switch (defaultTargetPlatform) {
        TargetPlatform.linux || TargetPlatform.windows || TargetPlatform.macOS => true,
        _ => false,
      };

  /// video_player has no Linux or Windows backend; those open the system
  /// player instead.
  static bool get inAppVideo =>
      defaultTargetPlatform != TargetPlatform.linux && defaultTargetPlatform != TargetPlatform.windows;

  /// share_plus cannot hand a file to another app on Linux, so Share is left out there.
  static bool get fileShare => defaultTargetPlatform != TargetPlatform.linux;
}
