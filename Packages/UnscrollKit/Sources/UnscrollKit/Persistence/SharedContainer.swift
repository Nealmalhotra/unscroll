import Foundation

/// Locates the App Group container shared by the app and its Screen Time extensions.
public enum SharedContainer {
    /// Must match the App Group in every target's entitlements (see project.yml).
    public static let appGroupID = "group.org.unscroll.shared"

    /// Falls back to Application Support when the group isn't available (tests, previews, misconfigured signing).
    public static func directory(fileManager: FileManager = .default) -> URL {
        if let group = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return group
        }
        let fallback = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fileManager.temporaryDirectory
        return fallback.appendingPathComponent("Unscroll", isDirectory: true)
    }
}

public enum StoreError: Error, LocalizedError {
    case readFailed(URL, underlying: Error)
    case writeFailed(URL, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case let .readFailed(url, error): "Couldn't read \(url.lastPathComponent): \(error.localizedDescription)"
        case let .writeFailed(url, error): "Couldn't save \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }
}

/// Reads and writes one Codable value as JSON with atomic replacement.
public struct JSONFile<Value: Codable & Sendable>: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        // Lossless (Double) dates so values round-trip exactly.
        encoder.dateEncodingStrategy = .deferredToDate
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }

    /// Returns nil when the file doesn't exist yet; throws when it exists but can't be decoded.
    public func load() throws -> Value? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try Self.decoder.decode(Value.self, from: Data(contentsOf: url))
        } catch {
            throw StoreError.readFailed(url, underlying: error)
        }
    }

    public func save(_ value: Value) throws {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(value).write(to: url, options: [.atomic])
        } catch {
            throw StoreError.writeFailed(url, underlying: error)
        }
    }
}
