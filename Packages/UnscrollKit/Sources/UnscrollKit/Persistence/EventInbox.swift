import Foundation

/// A drop box of `ExtensionEvent` files. Extensions `post`; the app `drain`s.
/// One file per event means concurrent extension processes never overwrite each other.
public struct EventInbox: Sendable {
    public let directory: URL

    public init(root: URL = SharedContainer.directory()) {
        directory = root.appendingPathComponent("inbox", isDirectory: true)
    }

    public func post(_ event: ExtensionEvent) throws {
        try JSONFile<ExtensionEvent>(url: directory.appendingPathComponent("\(event.id.uuidString).json")).save(event)
    }

    /// Returns all pending events plus the files they came from. Unreadable files are reported, not dropped silently.
    public func pending() -> (events: [ExtensionEvent], files: [URL], failures: [URL]) {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let jsonFiles = urls.filter { $0.pathExtension == "json" }
        var events: [ExtensionEvent] = []
        var failures: [URL] = []
        for url in jsonFiles {
            if let event = try? JSONFile<ExtensionEvent>(url: url).load() {
                events.append(event)
            } else {
                failures.append(url)
            }
        }
        return (events, jsonFiles, failures)
    }

    /// Call after the events have been applied and the new state was saved.
    public func acknowledge(_ files: [URL]) {
        for url in files { try? FileManager.default.removeItem(at: url) }
    }
}
