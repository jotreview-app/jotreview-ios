import Foundation

/// Manages a stable anonymous visitor identifier persisted in `UserDefaults`.
///
/// The visitor ID is used for anonymous vote attribution — the same concept
/// as the JavaScript SDK's `localStorage` visitor ID. It is a UUID string
/// generated once per device and reused across sessions.
internal enum VisitorIdStore {

    private static let key = "com.jotreview.sdk.visitorId"

    /// Returns the existing visitor ID or generates and persists a new one.
    static func getOrCreate() -> String {
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let newId = UUID().uuidString.lowercased()
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    /// Clears the stored visitor ID. Primarily useful for testing.
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
