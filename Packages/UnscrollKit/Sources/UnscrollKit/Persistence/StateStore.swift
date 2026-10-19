import Foundation

/// Serializes access to the app's persisted state. Only the host app writes this file.
public actor StateStore {
    private let file: JSONFile<AppState>
    private var cached: AppState?

    public init(directory: URL = SharedContainer.directory()) {
        file = JSONFile(url: directory.appendingPathComponent("state.json"))
    }

    public func load() throws -> AppState {
        if let cached { return cached }
        let state = try file.load() ?? AppState()
        cached = state
        return state
    }

    public func save(_ state: AppState) throws {
        try file.save(state)
        cached = state
    }

    /// Loads, transforms and saves in one step.
    @discardableResult
    public func update(_ transform: @Sendable (AppState) -> AppState) throws -> AppState {
        let next = transform(try load())
        try save(next)
        return next
    }

    /// Moves an unreadable state file aside so the app can start fresh instead of crashing.
    public func quarantineCorruptFile() throws {
        let corrupt = file.url.deletingPathExtension().appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
        if FileManager.default.fileExists(atPath: file.url.path) {
            try FileManager.default.moveItem(at: file.url, to: corrupt)
        }
        cached = nil
    }
}
