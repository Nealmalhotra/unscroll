import Foundation
import Observation
import os
import UnscrollKit

/// Leaderboards and groups. Uses a self-hosted server when configured; otherwise
/// leaderboards fall back to the offline simulated league and groups are unavailable.
@MainActor
@Observable
final class SocialService {
    enum FeedKind: String { case sessionStarted, sessionCompleted, sessionBroken, goalMet, goalMissed }

    private(set) var serverURL: URL?
    private(set) var handle: String?
    private(set) var groups: [GroupSummary] = []
    private(set) var lastError: String?
    private let defaults: UserDefaults
    private let log = Logger(subsystem: "org.unscroll", category: "social")
    private static let urlKey = "serverURL"
    private static let handleKey = "serverHandle"
    private static let tokenAccount = "token"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        serverURL = defaults.string(forKey: Self.urlKey).flatMap(URL.init(string:))
        handle = defaults.string(forKey: Self.handleKey)
    }

    var isConnected: Bool { serverURL != nil && Keychain.read(Self.tokenAccount) != nil }

    private var client: APIClient? {
        guard let serverURL else { return nil }
        return APIClient(baseURL: serverURL, token: Keychain.read(Self.tokenAccount))
    }

    /// Validates the URL, registers the handle and stores the token.
    func connect(urlString: String, handle: String) async -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, ["https", "http"].contains(scheme), url.host != nil else {
            lastError = "Enter a full server URL, like https://unscroll.example.com"
            return false
        }
        guard handle.range(of: "^[A-Za-z0-9_]{3,20}$", options: .regularExpression) != nil else {
            lastError = "Handles are 3–20 letters, numbers or underscores."
            return false
        }
        do {
            let user: RegisteredUser = try await APIClient(baseURL: url, token: nil).send("POST", "v1/users", body: ["handle": handle])
            Keychain.write(user.token, account: Self.tokenAccount)
            defaults.set(url.absoluteString, forKey: Self.urlKey)
            defaults.set(user.handle, forKey: Self.handleKey)
            serverURL = url
            self.handle = user.handle
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func disconnect() {
        Keychain.write(nil, account: Self.tokenAccount)
        defaults.removeObject(forKey: Self.urlKey)
        defaults.removeObject(forKey: Self.handleKey)
        serverURL = nil
        handle = nil
        groups = []
    }

    func syncWeek(state: AppState, week: WeekID) async {
        guard isConnected, let client else { return }
        let minutes = state.days.values
            .filter { week.contains($0.day.startDate()) }
            .reduce(0) { $0 + $1.screenMinutesAtLeast }
        struct Body: Encodable { let weekId: String; let xp: Int; let screenMinutes: Int }
        do {
            let _: WeekStats = try await client.send("PUT", "v1/me/week", body: Body(weekId: week.description, xp: state.weeklyXP(week), screenMinutes: min(20_160, minutes)))
        } catch {
            log.error("Week sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func league(week: WeekID) async -> ServerLeague? {
        guard isConnected, let client else { return nil }
        do {
            return try await client.get("v1/me/league", query: ["weekId": week.description])
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func loadGroups() async {
        guard isConnected, let client else { return }
        do {
            groups = try await client.get("v1/groups")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func createGroup(name: String) async -> GroupSummary? {
        await mutateGroups { try await $0.send("POST", "v1/groups", body: ["name": name]) }
    }

    func joinGroup(code: String) async -> GroupSummary? {
        let cleaned = code.uppercased().filter { $0.isLetter || $0.isNumber }
        guard cleaned.count == 8 else {
            lastError = "Invite codes are 8 characters."
            return nil
        }
        return await mutateGroups { try await $0.send("POST", "v1/groups/join", body: ["inviteCode": cleaned]) }
    }

    func leaveGroup(_ id: String) async {
        struct Left: Decodable { let left: Bool }
        let _: Left? = await mutateGroups { try await $0.send("POST", "v1/groups/\(id)/leave", body: [String: String]()) }
    }

    private func mutateGroups<T: Decodable>(_ call: (APIClient) async throws -> T) async -> T? {
        guard let client else {
            lastError = "Connect to a server first (Profile › Social server)."
            return nil
        }
        do {
            let result = try await call(client)
            await loadGroups()
            lastError = nil
            return result
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func groupDetail(_ id: String, week: WeekID) async -> GroupDetail? {
        guard let client else { return nil }
        do {
            return try await client.get("v1/groups/\(id)", query: ["weekId": week.description])
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    /// Posts to a group's feed (session started/completed etc). Silently skipped when offline.
    func post(kind: FeedKind, minutes: Int?, groupID: String?) async {
        guard let groupID, let client else { return }
        struct Body: Encodable { let kind: String; let minutes: Int? }
        do {
            struct Item: Decodable { let kind: String }
            let _: Item = try await client.send("POST", "v1/groups/\(groupID)/feed", body: Body(kind: kind.rawValue, minutes: minutes.map { min(1440, $0) }))
        } catch {
            log.error("Feed post failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
