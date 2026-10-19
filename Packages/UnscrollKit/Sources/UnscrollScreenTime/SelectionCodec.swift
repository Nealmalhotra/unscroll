#if os(iOS)
import FamilyControls
import Foundation
import ManagedSettings

/// `FamilyActivitySelection` is Codable; the core stores it as opaque Data.
public enum SelectionCodec {
    public static func encode(_ selection: FamilyActivitySelection) -> Data {
        (try? JSONEncoder().encode(selection)) ?? Data()
    }

    public static func decode(_ data: Data) -> FamilyActivitySelection {
        guard !data.isEmpty, let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    public static func isEmpty(_ data: Data) -> Bool {
        let selection = decode(data)
        return selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty
    }

    public static func itemCount(_ data: Data) -> Int {
        let selection = decode(data)
        return selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    public static func contains(_ data: Data, application: ApplicationToken?, category: ActivityCategoryToken?) -> Bool {
        let selection = decode(data)
        if let application, selection.applicationTokens.contains(application) { return true }
        if let category, selection.categoryTokens.contains(category) { return true }
        return false
    }

    public static func contains(_ data: Data, webDomain: WebDomainToken?) -> Bool {
        guard let webDomain else { return false }
        return decode(data).webDomainTokens.contains(webDomain)
    }
}
#endif
