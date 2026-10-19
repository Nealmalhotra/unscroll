#if os(iOS)
import Foundation
import UserNotifications

/// Local notifications from extensions and the app (doomscroll alerts, session start/end).
public enum Nudges {
    public static func send(title: String, body: String, after seconds: TimeInterval = 1) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger))
    }
}
#endif
