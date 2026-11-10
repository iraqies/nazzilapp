import 'dart:io';

abstract final class Platforms {
  /// Android and iOS have the native host (notifications, share sheet,
  /// tagging, gallery); desktops do this in Dart.
  static bool get mobile => Platform.isAndroid || Platform.isIOS;

  static bool get desktop => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  /// video_player has no Linux or Windows backend; those open the system
  /// player instead.
  static bool get inAppVideo => !(Platform.isLinux || Platform.isWindows);
}
