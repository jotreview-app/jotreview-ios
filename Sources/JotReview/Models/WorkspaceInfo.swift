import Foundation

/// Workspace display configuration returned by the `/api/widget/v1/init` endpoint.
public struct WorkspaceInfo: Codable, Sendable {
    /// The workspace display name.
    public let name: String

    /// URL-friendly slug used in public board URLs.
    public let slug: String

    /// Optional URL to the workspace logo image.
    public let logoURL: String?

    /// Hex color string (e.g. "#005bc4") for branding.
    public let primaryColor: String?

    /// Color theme preference — typically "light" or "dark".
    public let theme: String?

    /// Language / locale code (e.g. "en", "es").
    public let language: String?

    enum CodingKeys: String, CodingKey {
        case name
        case slug
        case logoURL = "logo_url"
        case primaryColor = "primary_color"
        case theme
        case language
    }
}
