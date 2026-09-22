import Foundation
import UserNotifications

let newContentNotificationsKey = "newContentNotificationsEnabled"

/// Local notifications for newly added content. There's no push server
/// behind this app (no backend at all -- see ContentRepository), so this
/// can only notify when the app itself checks for new content: on launch,
/// pull-to-refresh, or the Settings "Refresh Content" button. It cannot
/// notify while the app is fully closed the way a real push notification
/// would.
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var isAuthorized = false

    private init() {
        Task { await refreshAuthorizationStatus() }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        isAuthorized = granted
        return granted
    }

    func notifyNewContent(_ items: [MediaItem]) {
        guard UserDefaults.standard.bool(forKey: newContentNotificationsKey), isAuthorized, !items.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default
        if items.count == 1 {
            content.title = "New content added"
            content.body = items[0].title
        } else {
            content.title = "New content added"
            content.body = "\(items.count) new items are now available."
        }

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
