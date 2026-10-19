import Foundation

/// Pure state transitions. Each returns a new `AppState`; nothing is mutated in place.
extension AppState {
    // MARK: Days

    /// Makes sure a record exists for `day`, seeded with today's goal and intentions.
    public func ensuringDay(_ day: DayKey) -> AppState {
        guard days[day] == nil else { return self }
        let record = DayRecord(
            day: day,
            goalMinutes: profile.dailyGoalMinutes,
            trackedIntentions: Set(intentions.map(\.id))
        )
        return with(\.days, days.merging([day: record]) { old, _ in old })
    }

    func updatingDay(_ day: DayKey, _ transform: (DayRecord) -> DayRecord) -> AppState {
        let seeded = ensuringDay(day)
        guard let record = seeded.days[day] else { return seeded }
        return seeded.with(\.days, seeded.days.merging([day: transform(record)]) { _, new in new })
    }

    func awarding(_ amount: Int, _ reason: XPReason, _ note: String, at date: Date) -> AppState {
        guard amount > 0 else { return self }
        return with(\.xpLedger, xpLedger + [XPEntry(at: date, amount: amount, reason: reason, note: note)])
    }

    // MARK: Extension events

    /// Applies events left by the Screen Time extensions. Idempotent per event ID.
    public func applying(_ events: [ExtensionEvent], calendar: Calendar = .current) -> AppState {
        events.sorted { $0.at < $1.at }.reduce(self) { state, event in
            guard !state.processedEventIDs.contains(event.id) else { return state }
            let updated = state.applying(event, calendar: calendar)
            let ids = Array((updated.processedEventIDs + [event.id]).suffix(Self.processedEventMemory))
            return updated.with(\.processedEventIDs, ids)
        }
    }

    func applying(_ event: ExtensionEvent, calendar: Calendar) -> AppState {
        let day = DayKey(event.at, calendar: calendar)
        switch event.kind {
        case let .usageMilestone(minutes):
            return updatingDay(day) { $0.with(\.screenMinutesAtLeast, max($0.screenMinutesAtLeast, minutes)) }
        case .goalExceeded:
            return updatingDay(day) {
                $0.with(\.goalExceeded, true).with(\.screenMinutesAtLeast, max($0.screenMinutesAtLeast, $0.goalMinutes))
            }
        case let .intentionLimitReached(id):
            return updatingDay(day) { $0.with(\.brokenIntentions, $0.brokenIntentions.union([id])) }
        case let .intentionOpened(id):
            return applyingOpen(intentionID: id, day: day)
        case let .scheduledSessionStarted(session):
            guard activeSession == nil else { return self }
            return with(\.activeSession, session)
        case let .scheduledSessionEnded(planID):
            guard let active = activeSession, active.planID == planID else { return self }
            return endingSession(at: event.at, outcome: .completed, calendar: calendar).state
        case let .sessionBrokenFromShield(sessionID):
            guard activeSession?.id == sessionID, activeSession?.beastMode == false else { return self }
            return endingSession(at: event.at, outcome: .broken, calendar: calendar).state
        }
    }

    func applyingOpen(intentionID: UUID, day: DayKey) -> AppState {
        let limit = intentions.first { $0.id == intentionID }?.dailyOpens
        return updatingDay(day) { record in
            let count = (record.opens[intentionID] ?? 0) + 1
            let opened = record.with(\.opens, record.opens.merging([intentionID: count]) { _, new in new })
            guard let limit, count > limit else { return opened }
            return opened.with(\.brokenIntentions, opened.brokenIntentions.union([intentionID]))
        }
    }

    // MARK: Sessions

    public enum SessionError: Error, Equatable, LocalizedError {
        case alreadyRunning, tooShort, tooLong, beastModeLocked, noSession

        public var errorDescription: String? {
            switch self {
            case .alreadyRunning: "A session is already running."
            case .tooShort: "Sessions must be at least \(SessionRules.minimumMinutes) minutes."
            case .tooLong: "Sessions can be at most 12 hours."
            case .beastModeLocked: "Beast Mode is on. This session can't be ended early."
            case .noSession: "There's no session running."
            }
        }
    }

    public func startingSession(_ session: ActiveSession) -> Result<AppState, SessionError> {
        guard activeSession == nil else { return .failure(.alreadyRunning) }
        guard session.plannedMinutes >= SessionRules.minimumMinutes else { return .failure(.tooShort) }
        guard session.plannedMinutes <= SessionRules.maximumMinutes else { return .failure(.tooLong) }
        return .success(with(\.activeSession, session))
    }

    /// Ends the active session. Completed sessions earn XP; broken ones earn nothing.
    public func endingSession(
        at date: Date,
        outcome: SessionOutcome,
        calendar: Calendar = .current
    ) -> (state: AppState, record: SessionRecord?) {
        guard let active = activeSession else { return (self, nil) }
        let end = outcome == .completed ? min(date, active.endsAt) : date
        let minutes = max(0, Int(end.timeIntervalSince(active.startedAt) / 60))
        let xp = XPRules.sessionXP(minutes: minutes, beastMode: active.beastMode, outcome: outcome)
        let record = SessionRecord(
            id: active.id, name: active.name, startedAt: active.startedAt, endedAt: end,
            plannedMinutes: active.plannedMinutes, beastMode: active.beastMode, outcome: outcome, xpAwarded: xp
        )
        let state = with(\.activeSession, nil)
            .with(\.sessionHistory, sessionHistory + [record])
            .awarding(xp, .sessionCompleted, active.name, at: end)
            .completingQuests(on: DayKey(active.startedAt, calendar: calendar), at: end, includeDayEnd: false, calendar: calendar)
        return (state, record)
    }

    /// User-initiated early stop. Refused in Beast Mode.
    public func breakingSession(at date: Date, calendar: Calendar = .current) -> Result<AppState, SessionError> {
        guard let active = activeSession else { return .failure(.noSession) }
        if active.isFinished(at: date) {
            return .success(endingSession(at: date, outcome: .completed, calendar: calendar).state)
        }
        guard !active.beastMode else { return .failure(.beastModeLocked) }
        return .success(endingSession(at: date, outcome: .broken, calendar: calendar).state)
    }

    /// Completes the active session if its time is up (e.g. app was suspended during the session).
    public func reconcilingSession(at date: Date, calendar: Calendar = .current) -> AppState {
        guard let active = activeSession, active.isFinished(at: date) else { return self }
        return endingSession(at: active.endsAt, outcome: .completed, calendar: calendar).state
    }

    // MARK: Small actions

    public func markingTipRead(on day: DayKey, at date: Date, calendar: Calendar = .current) -> AppState {
        guard days[day]?.tipRead != true else { return self }
        return updatingDay(day) { $0.with(\.tipRead, true) }
            .awarding(XPRules.tipRead, .tipRead, "Read the tip of the day", at: date)
            .completingQuests(on: day, at: date, includeDayEnd: false, calendar: calendar)
    }

    public func redeeming(_ reward: Reward, at date: Date) -> Result<AppState, RedemptionError> {
        RewardLedger.redeem(reward, ledger: xpLedger, redemptions: redemptions, at: date)
            .map { with(\.redemptions, redemptions + [$0]) }
    }

    public func clearingPartnerAlerts() -> AppState { with(\.pendingPartnerAlerts, []) }

    /// Updates the profile; a new daily goal also applies to today, because the monitor's
    /// goal threshold is re-registered immediately.
    public func updatingProfile(_ profile: Profile, today: DayKey) -> AppState {
        with(\.profile, profile).updatingDay(today) { $0.with(\.goalMinutes, profile.dailyGoalMinutes) }
    }
}

extension DayRecord {
    public func with<T>(_ keyPath: WritableKeyPath<DayRecord, T>, _ value: T) -> DayRecord {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
}
