import Foundation
import Testing
@testable import UnscrollKit

@Suite("Persistence")
struct PersistenceTests {
    @Test func stateStoreRoundTrips() async throws {
        let dir = Fixtures.tempDirectory()
        let store = StateStore(directory: dir)
        #expect(try await store.load().intentions.isEmpty)
        let intention = Intention(name: "Reddit", dailyOpens: 2)
        let saved = try await store.update { $0.with(\.intentions, [intention]).ensuringDay(Fixtures.day) }
        let reloaded = try await StateStore(directory: dir).load()
        #expect(reloaded == saved)
        #expect(reloaded.intentions == [intention])
    }

    @Test func corruptStateThrowsAndCanBeQuarantined() async throws {
        let dir = Fixtures.tempDirectory()
        try Data("{ not json".utf8).write(to: dir.appendingPathComponent("state.json"))
        let store = StateStore(directory: dir)
        await #expect(throws: StoreError.self) { try await store.load() }
        try await store.quarantineCorruptFile()
        #expect(try await store.load().intentions.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(files.contains { $0.contains("corrupt") })
    }

    @Test func inboxPostsAndAcknowledges() throws {
        let inbox = EventInbox(root: Fixtures.tempDirectory())
        #expect(inbox.pending().events.isEmpty)
        let event = ExtensionEvent(kind: .goalExceeded)
        try inbox.post(event)
        try Data("garbage".utf8).write(to: inbox.directory.appendingPathComponent("bad.json"))
        let pending = inbox.pending()
        #expect(pending.events == [event])
        #expect(pending.failures.count == 1)
        inbox.acknowledge(pending.files)
        #expect(inbox.pending().files.isEmpty)
    }

    @Test func sharedConfigMirrorsState() throws {
        let dir = Fixtures.tempDirectory()
        let state = AppState(profile: Profile(dailyGoalMinutes: 75, doomscrollAlertsEnabled: false), intentions: [Intention(name: "X", dailyOpens: 1)])
        let config = SharedConfig(state: state, trackingSelectionData: Data([1, 2]))
        try SharedConfig.file(root: dir).save(config)
        #expect(SharedConfig.load(root: dir) == config)
        #expect(SharedConfig.load(root: Fixtures.tempDirectory()) == SharedConfig())
    }

    @Test func opensLedgerResetsDaily() throws {
        let dir = Fixtures.tempDirectory()
        let intention = Intention(name: "X", dailyOpens: 3)
        let ledger = OpensLedger(day: Fixtures.day).recordingOpen(intention.id, until: Date())
        try OpensLedger.file(root: dir).save(ledger)
        #expect(OpensLedger.load(today: Fixtures.day, root: dir).remaining(for: intention) == 2)
        let tomorrow = Fixtures.day.adding(days: 1, calendar: Fixtures.calendar)
        #expect(OpensLedger.load(today: tomorrow, root: dir).count(for: intention.id) == 0)
        #expect(ledger.remaining(for: Intention(name: "Y", dailyMinutes: 3)) == nil)
    }

    @Test func limitLedgerResetsDaily() throws {
        let dir = Fixtures.tempDirectory()
        let id = UUID()
        #expect(!LimitLedger.hasStarted(Fixtures.day, root: dir))
        try LimitLedger.file(root: dir).save(LimitLedger(day: Fixtures.day).reaching(id))
        #expect(LimitLedger.hasStarted(Fixtures.day, root: dir))
        #expect(LimitLedger.load(today: Fixtures.day, root: dir).reached == [id])
        #expect(LimitLedger.load(today: Fixtures.day.adding(days: 1, calendar: Fixtures.calendar), root: dir).reached.isEmpty)
    }

    @Test func storeErrorsDescribeFile() {
        let url = URL(fileURLWithPath: "/tmp/state.json")
        let error = NSError(domain: "x", code: 1)
        #expect(StoreError.readFailed(url, underlying: error).errorDescription?.contains("state.json") == true)
        #expect(StoreError.writeFailed(url, underlying: error).errorDescription?.contains("state.json") == true)
    }

    @Test func sharedContainerFallsBack() {
        #expect(SharedContainer.directory().path.isEmpty == false)
    }

    @Test func shieldLedgerTracksOverridesAndBrokenSessions() throws {
        let id = UUID(), session = UUID()
        let ledger = OpensLedger(day: Fixtures.day).overriding(id).breakingSession(session).recordingOpen(id, until: Date())
        #expect(ledger.overridden == [id])
        #expect(ledger.brokenSessions == [session])
        #expect(ledger.count(for: id) == 1)
    }

    @Test func scheduledSessionFileRoundTrips() throws {
        let dir = Fixtures.tempDirectory()
        #expect(ScheduledSessionFile.load(root: dir) == nil)
        let session = Fixtures.session(start: Date(), minutes: 30)
        try ScheduledSessionFile.file(root: dir).save(ScheduledSessionFile(session: session))
        #expect(ScheduledSessionFile.load(root: dir)?.id == session.id)
    }
}
