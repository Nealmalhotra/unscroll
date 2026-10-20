import Foundation
import Observation
import os
import UnscrollKit
import WidgetKit

/// The single source of truth for the UI. Holds an immutable `AppState` snapshot and
/// replaces it wholesale on every change, then persists and syncs side effects.
@MainActor
@Observable
final class AppModel {
    private(set) var state = AppState()
    private(set) var isLoaded = false
    var errorMessage: String?
    /// Encoded "All Apps & Categories" selection used for screen time tracking.
    private(set) var trackingSelection = Data()

    let screenTime: ScreenTimeService
    let social: SocialService
    private let store: StateStore
    private let inbox: EventInbox
    private let defaults: UserDefaults
    private let log = Logger(subsystem: "org.unscroll", category: "model")
    private static let trackingKey = "trackingSelection"

    init(
        store: StateStore = StateStore(),
        inbox: EventInbox = EventInbox(),
        screenTime: ScreenTimeService = ScreenTimeService(),
        social: SocialService = SocialService(),
        defaults: UserDefaults = UserDefaults(suiteName: SharedContainer.appGroupID) ?? .standard
    ) {
        self.store = store
        self.inbox = inbox
        self.screenTime = screenTime
        self.social = social
        self.defaults = defaults
        trackingSelection = defaults.data(forKey: Self.trackingKey) ?? Data()
    }

    var today: DayKey { DayKey(Date()) }
    var todayRecord: DayRecord { state.days[today] ?? DayRecord(day: today, goalMinutes: state.profile.dailyGoalMinutes) }
    var streak: StreakSummary { state.streak(today: today) }
    var currentWeek: WeekID { WeekID(Date()) }

    // MARK: Lifecycle

    func bootstrap() async {
        do {
            state = try await store.load()
        } catch {
            log.error("State load failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Your saved data couldn't be read, so Unscroll started fresh. A backup was kept."
            try? await store.quarantineCorruptFile()
            state = (try? await store.load()) ?? AppState()
        }
        #if DEBUG
        if DemoData.isRequested { state = DemoData.state() }
        #endif
        isLoaded = true
        await refresh()
    }

    /// Pulls extension events, closes finished days/sessions and rolls the league week.
    func refresh() async {
        let pending = inbox.pending()
        for failure in pending.failures { log.error("Unreadable event file \(failure.lastPathComponent, privacy: .public)") }
        let now = Date()
        let previousSession = state.activeSession
        let next = state
            .applying(pending.events)
            .reconcilingSession(at: now)
            .finalizingDays(before: today, at: now)
            .rollingLeague(to: WeekID(now))
        // Only delete the event files once the state that includes them is safely saved.
        if await commit(next) { inbox.acknowledge(pending.files) }
        if previousSession != nil, next.activeSession == nil { screenTime.endSession(previousSession) }
        await social.syncWeek(state: next, week: currentWeek)
    }

    /// Persists a new state and pushes the parts extensions need into the shared config.
    /// Returns false (and tells the user) when anything couldn't be written.
    @discardableResult
    func commit(_ next: AppState) async -> Bool {
        state = next
        do {
            try await store.save(next)
            try SharedConfig.file().save(SharedConfig(state: next, trackingSelectionData: trackingSelection))
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch {
            log.error("Save failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Couldn't save your changes. Please try again."
            return false
        }
    }

    func update(_ transform: (AppState) -> AppState) async {
        await commit(transform(state))
    }

    // MARK: Settings that need Screen Time re-registration

    func setTrackingSelection(_ data: Data) async {
        trackingSelection = data
        defaults.set(data, forKey: Self.trackingKey)
        await commit(state)
        resyncMonitoring()
    }

    func resyncMonitoring() {
        do {
            try screenTime.resync(config: SharedConfig(state: state, trackingSelectionData: trackingSelection))
        } catch {
            log.error("Monitoring sync failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Couldn't update Screen Time schedules: \(error.localizedDescription)"
        }
    }
}
