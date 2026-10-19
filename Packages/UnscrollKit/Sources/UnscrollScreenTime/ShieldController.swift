#if os(iOS)
import FamilyControls
import Foundation
import ManagedSettings
import UnscrollKit

/// Applies and removes shields. Sessions and each intention use separate named stores,
/// so clearing one never accidentally unblocks another.
public enum ShieldController {
    public static func applySession(_ session: ActiveSession) {
        let store = ManagedSettingsStore(named: .session)
        let selection = SelectionCodec.decode(session.selectionData)
        store.clearAllSettings()
        switch session.mode {
        case .blockSelected:
            store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
            store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
            store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        case .allowSelected:
            store.shield.applicationCategories = .all(except: selection.applicationTokens)
            store.shield.webDomainCategories = .all(except: selection.webDomainTokens)
        }
    }

    public static func clearSession() {
        ManagedSettingsStore(named: .session).clearAllSettings()
    }

    public static func shield(_ intention: Intention) {
        let store = ManagedSettingsStore(named: .intention(intention.id))
        let selection = SelectionCodec.decode(intention.selectionData)
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    public static func unshield(_ intentionID: UUID) {
        ManagedSettingsStore(named: .intention(intentionID)).clearAllSettings()
    }

    /// Start-of-day state: opens-limited intentions are shielded (every open is a deliberate choice),
    /// time-limited-only intentions are open until their allowance runs out.
    public static func resetIntentions(_ intentions: [Intention]) {
        for intention in intentions {
            if intention.dailyOpens != nil {
                shield(intention)
            } else {
                unshield(intention.id)
            }
        }
    }

    /// Removes stores for intentions that were deleted.
    public static func clearIntentions(except keep: [Intention], removed: [UUID]) {
        let kept = Set(keep.map(\.id))
        for id in removed where !kept.contains(id) { unshield(id) }
    }
}
#endif
