import Flutter
import UIKit

final class NazzilHost: NSObject {
  static let shared = NazzilHost()

  private var channel: FlutterMethodChannel?
  private var dartReady = false
  private var pendingLibrary = false
  private var pendingResume = false
  private var pendingCancel = false

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "nazzil/host", binaryMessenger: messenger)
    shared.channel = channel
    channel.setMethodCallHandler { call, result in
      shared.handle(call, result: result)
    }
  }

  static func emit(_ method: String, arguments: Any? = nil) {
    DispatchQueue.main.async {
      shared.channel?.invokeMethod(method, arguments: arguments)
    }
  }

  static func handleNotification(action: String, defaultTap: Bool) {
    let resume = action == "resume"
    let cancel = action == "cancel"
    let pause = action == "pause"
    let library = resume || cancel || defaultTap
    shared.dispatch(library: library, resume: resume, cancel: cancel, pause: pause)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "drain":
      dartReady = true
      result([
        "library": pendingLibrary,
        "resume": pendingResume,
        "cancel": pendingCancel,
      ])
      pendingLibrary = false
      pendingResume = false
      pendingCancel = false
    case "start":
      NazzilKeepAlive.start()
      NazzilNotifier.shared.progress(
        title: args.string("title") ?? "Nazzil",
        percent: args.int("percent") ?? 1
      )
      result(nil)
    case "progress":
      NazzilKeepAlive.start()
      NazzilNotifier.shared.progress(
        title: args.string("title") ?? "Nazzil",
        percent: args.int("percent") ?? 0
      )
      result(nil)
    case "paused":
      NazzilKeepAlive.stop()
      NazzilNotifier.shared.paused(
        title: args.string("title") ?? "Nazzil",
        percent: args.int("percent") ?? 0
      )
      result(nil)
    case "done":
      NazzilKeepAlive.stop()
      NazzilNotifier.shared.done(title: args.string("title") ?? "Nazzil", path: args.string("path"))
      result(nil)
    case "failed":
      NazzilKeepAlive.stop()
      NazzilNotifier.shared.failed(args.string("message") ?? "Download failed")
      result(nil)
    case "stop":
      NazzilKeepAlive.stop()
      NazzilNotifier.shared.cancel()
      result(nil)
    case "openFile":
      guard let path = args.string("path"), !path.isEmpty else {
        result(FlutterError(code: "missing", message: "No path", details: nil))
        return
      }
      if openFile(path) {
        result(nil)
      } else {
        result(FlutterError(code: "missing", message: "File is gone", details: nil))
      }
    case "tagAudio":
      guard let path = args.string("path"), !path.isEmpty else {
        result(FlutterError(code: "missing", message: "No path", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        let tagged = NazzilAudioTagger.apply(
          path: path,
          title: args.string("title") ?? "Nazzil",
          author: args.string("author"),
          coverPath: args.string("coverPath"),
          lyricsPlain: args.string("lyricsPlain"),
          lyricsSynced: args.string("lyricsSynced")
        )
        DispatchQueue.main.async { result(tagged) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func dispatch(library: Bool, resume: Bool, cancel: Bool, pause: Bool) {
    if let channel, dartReady {
      if library { channel.invokeMethod("opened", arguments: ["library": true]) }
      if pause { channel.invokeMethod("pause", arguments: nil) }
      if resume { channel.invokeMethod("resume", arguments: nil) }
      if cancel { channel.invokeMethod("cancel", arguments: nil) }
    } else {
      pendingLibrary = library || pendingLibrary
      pendingResume = resume || pendingResume
      pendingCancel = cancel || pendingCancel
    }
  }

  private func openFile(_ path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else { return false }
    guard let presenter = topController() else { return false }
    let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let pop = sheet.popoverPresentationController {
      pop.sourceView = presenter.view
      pop.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
    }
    presenter.present(sheet, animated: true)
    return true
  }

  private func topController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.flatMap(\.windows).first
    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }
}

private extension Dictionary where Key == String, Value == Any {
  func string(_ key: String) -> String? {
    if let value = self[key] as? String { return value }
    return nil
  }

  func int(_ key: String) -> Int? {
    if let value = self[key] as? Int { return value }
    if let value = self[key] as? NSNumber { return value.intValue }
    return nil
  }
}
