import Flutter
import UIKit

final class NazzilShare: NSObject, FlutterStreamHandler {
  static let shared = NazzilShare()
  static let pasteboardName = UIPasteboard.Name("com.nazzil.share")

  private var sink: FlutterEventSink?
  private var pending: [String] = []
  private var lastSent: String?
  private var lastInitial: String?
  private var methods: FlutterMethodChannel?

  static func register(messenger: FlutterBinaryMessenger) {
    let events = FlutterEventChannel(name: "nazzil/share", binaryMessenger: messenger)
    events.setStreamHandler(shared)
    let methods = FlutterMethodChannel(name: "nazzil/share/methods", binaryMessenger: messenger)
    shared.methods = methods
    methods.setMethodCallHandler { call, result in
      if call.method == "initial" {
        result(shared.lastInitial)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    shared.drainPasteboard()
  }

  static func handle(urls: [URL]) {
    urls.forEach { shared.ingest(from: $0) }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    pending.forEach { events($0) }
    pending.removeAll()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  func drainPasteboard() {
    if let named = UIPasteboard(name: Self.pasteboardName, create: false)?.string, !named.isEmpty {
      UIPasteboard(name: Self.pasteboardName, create: false)?.string = nil
      emit(named)
    }
  }

  func ingest(from url: URL) {
    if url.scheme?.lowercased() == "nazzil" {
      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
      if let value = items?.first(where: { $0.name == "url" })?.value, !value.isEmpty {
        emit(value)
        return
      }
    }
    emit(url.absoluteString)
  }

  func emit(_ raw: String) {
    let text = pickLink(from: raw) ?? raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.isEmpty || text == lastSent { return }
    lastSent = text
    lastInitial = text
    if let sink {
      sink(text)
    } else {
      pending.append(text)
    }
  }

  private func pickLink(from text: String) -> String? {
    let chunks = text
      .components(separatedBy: CharacterSet.newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    let match = chunks.first { candidate in
      let lower = candidate.lowercased()
      return lower.contains("http") ||
        lower.contains("tiktok") ||
        lower.contains("youtu") ||
        lower.contains("instagram") ||
        lower.contains("facebook") ||
        lower.contains("fb.watch")
    }
    return match ?? chunks.first
  }
}
