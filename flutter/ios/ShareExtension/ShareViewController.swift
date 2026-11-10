import UIKit
import UniformTypeIdentifiers

@objc(ShareViewController)
final class ShareViewController: UIViewController {
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    view.backgroundColor = .clear
    Task { await handOff() }
  }

  private func handOff() async {
    let text = await extract()
    if let text, !text.isEmpty {
      UIPasteboard.general.string = text
      if let board = UIPasteboard(name: UIPasteboard.Name("com.nazzil.share"), create: true) {
        board.string = text
      }
      openHost(text)
    }
    extensionContext?.completeRequest(returningItems: nil)
  }

  private func extract() async -> String? {
    let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
    var chunks: [String] = []
    for item in items {
      if let text = item.attributedContentText?.string, !text.isEmpty {
        chunks.append(text)
      }
      for provider in item.attachments ?? [] {
        if let value = await loadString(provider, UTType.url) { chunks.append(value) }
        if let value = await loadString(provider, UTType.plainText) { chunks.append(value) }
        if let value = await loadString(provider, UTType.fileURL) { chunks.append(value) }
      }
    }
    return chunks.first { candidate in
      let lower = candidate.lowercased()
      return lower.contains("http") ||
        lower.contains("tiktok") ||
        lower.contains("youtu") ||
        lower.contains("instagram") ||
        lower.contains("facebook") ||
        lower.contains("fb.watch")
    } ?? chunks.first
  }

  private func loadString(_ provider: NSItemProvider, _ type: UTType) async -> String? {
    guard provider.hasItemConformingToTypeIdentifier(type.identifier) else { return nil }
    return await withCheckedContinuation { continuation in
      provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, _ in
        if let url = item as? URL {
          continuation.resume(returning: url.absoluteString)
        } else if let text = item as? String {
          continuation.resume(returning: text)
        } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
          continuation.resume(returning: text)
        } else {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  private func openHost(_ text: String) {
    var components = URLComponents()
    components.scheme = "nazzil"
    components.host = "import"
    components.queryItems = [URLQueryItem(name: "url", value: text)]
    guard let url = components.url else { return }

    var responder: UIResponder? = self
    while let current = responder {
      if let application = current as? UIApplication {
        open(url, with: application)
        return
      }
      responder = current.next
    }
  }

  /// iOS 18 ignores the old one-argument openURL:, so the app is opened with
  /// open(_:options:completionHandler:). That method is marked unavailable in
  /// extensions, hence the call through the runtime.
  private func open(_ url: URL, with application: UIApplication) {
    typealias OpenFunction = @convention(c) (
      AnyObject, Selector, NSURL, NSDictionary, (@convention(block) (Bool) -> Void)?
    ) -> Void
    let modern = NSSelectorFromString("openURL:options:completionHandler:")
    if application.responds(to: modern) {
      let function = unsafeBitCast(application.method(for: modern), to: OpenFunction.self)
      function(application, modern, url as NSURL, NSDictionary(), nil)
      return
    }
    let legacy = NSSelectorFromString("openURL:")
    if application.responds(to: legacy) {
      application.perform(legacy, with: url)
    }
  }
}
