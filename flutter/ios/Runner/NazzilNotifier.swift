import UIKit
import UserNotifications

final class NazzilNotifier: NSObject, UNUserNotificationCenterDelegate {
  static let shared = NazzilNotifier()
  static let identifier = "nazzil.download"

  func setup() {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    let pause = UNNotificationAction(identifier: "pause", title: "Pause", options: [])
    let cancel = UNNotificationAction(identifier: "cancel", title: "Cancel", options: [.destructive])
    let resume = UNNotificationAction(identifier: "resume", title: "Resume", options: [.foreground])
    center.setNotificationCategories([
      UNNotificationCategory(identifier: "nazzil.download.progress", actions: [pause, cancel], intentIdentifiers: [], options: []),
      UNNotificationCategory(identifier: "nazzil.download.paused", actions: [resume, cancel], intentIdentifiers: [], options: []),
      UNNotificationCategory(identifier: "nazzil.download.idle", actions: [], intentIdentifiers: [], options: []),
    ])
    center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
  }

  func progress(title: String, percent: Int) {
    let shown = min(max(percent, 0), 100)
    post(
      title: "Downloading…",
      body: "\(shown)%  ·  \(title)",
      type: "progress",
      actions: ["pause", "cancel"]
    )
  }

  func paused(title: String, percent: Int) {
    let shown = min(max(percent, 0), 100)
    post(
      title: "Paused",
      body: "\(shown)%  ·  \(title)",
      type: "paused",
      actions: ["resume", "cancel"]
    )
  }

  func done(title: String, path: String?) {
    post(title: "Saved", body: title, type: "done", actions: [], path: path)
  }

  func failed(_ message: String) {
    post(title: "Download failed", body: message, type: "failed", actions: [])
  }

  func cancel() {
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier])
  }

  private func post(title: String, body: String, type: String, actions: [String], path: String? = nil) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = type == "progress" || type == "paused" ? nil : .default
    content.categoryIdentifier = type == "progress"
      ? "nazzil.download.progress"
      : type == "paused" ? "nazzil.download.paused" : "nazzil.download.idle"
    content.userInfo = [
      "type": type,
      "actions": actions,
      "path": path ?? "",
    ]
    content.interruptionLevel = type == "progress" ? .passive : .active
    let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let type = notification.request.content.userInfo["type"] as? String
    if type == "progress" {
      completionHandler([])
    } else {
      completionHandler([.banner, .list, .sound])
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let action = response.actionIdentifier
    let defaultTap = action == UNNotificationDefaultActionIdentifier
    NazzilHost.handleNotification(action: action, defaultTap: defaultTap)
    completionHandler()
  }
}
