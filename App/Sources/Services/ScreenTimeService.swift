import FamilyControls
import Foundation
import Observation
import os
import UnscrollKit
import UnscrollScreenTime
import UserNotifications

/// Wraps Apple's Screen Time frameworks for the UI layer.
@MainActor
@Observable
final class ScreenTimeService {
    private(set) var authorization: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    private let log = Logger(subsystem: "org.unscroll", category: "screentime")

    var isAuthorized: Bool { authorization == .approved }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        authorization = AuthorizationCenter.shared.authorizationStatus
    }

    func refreshStatus() {
        authorization = AuthorizationCenter.shared.authorizationStatus
    }

    func requestNotifications() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            log.error("Notification permission failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Registers the daily tracker, scheduled plans and intention shields.
    func resync(config: SharedConfig) throws {
        guard isAuthorized else { return }
        try ActivityScheduler.startDaily(config: config)
        try ActivityScheduler.schedulePlans(config.plans)
        let today = DayKey(Date())
        let limits = LimitLedger.load(today: today)
        let opens = OpensLedger.load(today: today)
        for intention in config.intentions {
            let unlocked = (opens.unlockedUntil[intention.id] ?? .distantPast) > Date()
            let timeUp = limits.reached.contains(intention.id) && !opens.overridden.contains(intention.id)
            if timeUp || (intention.dailyOpens != nil && !unlocked) {
                ShieldController.shield(intention)
            } else {
                ShieldController.unshield(intention.id)
            }
        }
    }

    func beginSession(_ session: ActiveSession) {
        ShieldController.applySession(session)
        do {
            try ActivityScheduler.monitorSessionEnd(session)
        } catch {
            // The app also reconciles on launch, so the session still ends, just later.
            log.error("Couldn't schedule session end: \(error.localizedDescription, privacy: .public)")
        }
    }

    func endSession(_ session: ActiveSession?) {
        ShieldController.clearSession()
        if let session { ActivityScheduler.stopSessionMonitor(session.id) }
    }

    func removeIntention(_ id: UUID) {
        ShieldController.unshield(id)
    }
}
