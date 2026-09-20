import Flutter
import UIKit

enum NazzilPlugin {
  static func register(messenger: FlutterBinaryMessenger) {
    NazzilShare.register(messenger: messenger)
    NazzilHost.register(messenger: messenger)
  }
}
