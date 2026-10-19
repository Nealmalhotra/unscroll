import Foundation

/// Minimal client for the self-hostable Unscroll server (see /Server).
/// Every response is the envelope `{success, data, error}`.
struct APIClient: Sendable {
    let baseURL: URL
    let token: String?
    var session: URLSession = .shared

    struct Envelope<T: Decodable>: Decodable {
        let success: Bool
        let data: T?
        let error: String?
    }

    enum APIError: Error, LocalizedError {
        case server(String)
        case invalidResponse
        case transport(Error)

        var errorDescription: String? {
            switch self {
            case let .server(message): message
            case .invalidResponse: "The server sent an unexpected response."
            case let .transport(error): "Couldn't reach the server: \(error.localizedDescription)"
            }
        }
    }

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try await send("GET", path, query: query, body: Optional<[String: String]>.none)
    }

    func send<T: Decodable, B: Encodable>(_ method: String, _ path: String, query: [String: String] = [:], body: B?) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        guard let url = components?.url else { throw APIError.invalidResponse }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = method
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let data: Data
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
        guard let envelope = try? JSONDecoder().decode(Envelope<T>.self, from: data) else { throw APIError.invalidResponse }
        guard envelope.success, let payload = envelope.data else { throw APIError.server(envelope.error ?? "Unknown server error") }
        return payload
    }
}

// MARK: Server DTOs

struct RegisteredUser: Decodable, Sendable { let id: String; let handle: String; let token: String }
struct ServerStanding: Decodable, Sendable, Identifiable { var id: String { handle }; let handle: String; let xp: Int; let rank: Int; let isMe: Bool }
struct ServerLeague: Decodable, Sendable { let weekId: String; let tier: String; let standings: [ServerStanding]; let promoteCount: Int; let demoteCount: Int }
struct GroupSummary: Decodable, Sendable, Identifiable, Hashable { let id: String; let name: String; let inviteCode: String; let memberCount: Int }
struct GroupMember: Decodable, Sendable, Identifiable { var id: String { handle }; let handle: String; let xp: Int; let screenMinutes: Int }
struct FeedItem: Decodable, Sendable, Identifiable { var id: String { "\(handle)-\(at)-\(kind)" }; let handle: String; let kind: String; let minutes: Int?; let at: String }
struct GroupDetail: Decodable, Sendable { let id: String; let name: String; let inviteCode: String; let members: [GroupMember]; let feed: [FeedItem] }
struct WeekStats: Decodable, Sendable { let weekId: String; let xp: Int; let screenMinutes: Int }
