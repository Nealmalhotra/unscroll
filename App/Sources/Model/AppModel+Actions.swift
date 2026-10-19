import Foundation
import UnscrollKit

/// User intents. Each validates input, produces a new state and applies side effects.
extension AppModel {
    // MARK: Onboarding & profile

    func completeOnboarding(profile: Profile) async {
        await update { $0.with(\.profile, profile.with(\.onboardingComplete, true)).ensuringDay(today) }
        resyncMonitoring()
        await screenTime.requestNotifications()
    }

    func updateProfile(_ profile: Profile) async {
        await update { $0.updatingProfile(profile, today: today) }
        resyncMonitoring()
    }

    // MARK: Sessions

    func startSession(name: String, minutes: Int, mode: BlockMode, beastMode: Bool, selection: Data, groupID: String? = nil) async {
        let now = Date()
        let session = ActiveSession(
            name: name.isEmpty ? "Present Session" : name, startedAt: now,
            endsAt: now.addingTimeInterval(TimeInterval(minutes * 60)),
            mode: mode, beastMode: beastMode, selectionData: selection, groupID: groupID
        )
        switch state.startingSession(session) {
        case let .success(next):
            await commit(next)
            screenTime.beginSession(session)
            await social.post(kind: .sessionStarted, minutes: minutes, groupID: groupID)
        case let .failure(error):
            errorMessage = error.localizedDescription
        }
    }

    func endSessionEarly() async {
        let session = state.activeSession
        switch state.breakingSession(at: Date()) {
        case let .success(next):
            await commit(next)
            screenTime.endSession(session)
            let outcome = next.sessionHistory.last?.outcome
            await social.post(kind: outcome == .completed ? .sessionCompleted : .sessionBroken, minutes: next.sessionHistory.last?.actualMinutes, groupID: session?.groupID)
        case let .failure(error):
            errorMessage = error.localizedDescription
        }
    }

    func savePlan(_ plan: SessionPlan) async {
        guard plan.isValid else {
            errorMessage = plan.validationErrors.joined(separator: "\n")
            return
        }
        let isNew = !state.plans.contains { $0.id == plan.id }
        guard !isNew || state.plans.count < SessionRules.maximumPlans else {
            errorMessage = "You can have up to \(SessionRules.maximumPlans) scheduled sessions (an iOS limit)."
            return
        }
        await update { state in
            let others = state.plans.filter { $0.id != plan.id }
            return state.with(\.plans, others + [plan])
        }
        resyncMonitoring()
    }

    func deletePlan(_ id: UUID) async {
        await update { $0.with(\.plans, $0.plans.filter { $0.id != id }) }
        resyncMonitoring()
    }

    // MARK: Intentions

    func saveIntention(_ intention: Intention) async {
        guard intention.isValid else {
            errorMessage = intention.validationErrors.joined(separator: "\n")
            return
        }
        await update { state in
            let others = state.intentions.filter { $0.id != intention.id }
            let days = state.days.mapValues { record in
                record.day == today ? record.with(\.trackedIntentions, record.trackedIntentions.union([intention.id])) : record
            }
            return state.with(\.intentions, others + [intention]).with(\.days, days)
        }
        resyncMonitoring()
    }

    func deleteIntention(_ id: UUID) async {
        await update { $0.with(\.intentions, $0.intentions.filter { $0.id != id }) }
        screenTime.removeIntention(id)
        resyncMonitoring()
    }

    // MARK: Rewards, tips, accountability

    func readTip() async {
        await update { $0.markingTipRead(on: today, at: Date()) }
    }

    func saveReward(_ reward: Reward) async {
        guard reward.validationErrors.isEmpty else {
            errorMessage = reward.validationErrors.joined(separator: "\n")
            return
        }
        await update { state in state.with(\.rewards, state.rewards.filter { $0.id != reward.id } + [reward]) }
    }

    func deleteReward(_ id: UUID) async {
        await update { $0.with(\.rewards, $0.rewards.filter { $0.id != id }) }
    }

    func redeem(_ reward: Reward) async -> Bool {
        switch state.redeeming(reward, at: Date()) {
        case let .success(next):
            await commit(next)
            return true
        case let .failure(error):
            errorMessage = error.localizedDescription
            return false
        }
    }

    func savePartner(_ partner: AccountabilityPartner?) async {
        if let partner, !partner.validationErrors.isEmpty {
            errorMessage = partner.validationErrors.joined(separator: "\n")
            return
        }
        await update { $0.with(\.partner, partner) }
    }

    func savePledge(_ pledge: Pledge?) async {
        await update { $0.with(\.pledge, pledge) }
    }

    func settlePledge() async {
        guard let pledge = state.pledge else { return }
        await update { $0.with(\.pledge, Pledge(amountDollars: pledge.amountDollars, causeName: pledge.causeName, causeURL: pledge.causeURL, owed: 0)) }
    }

    func clearPartnerAlerts() async {
        await update { $0.clearingPartnerAlerts() }
    }
}
