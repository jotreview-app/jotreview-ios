import Foundation

/// A published changelog entry returned by the `/api/widget/v1/changelog` endpoint.
public struct ChangelogEntry: Codable, Identifiable, Sendable {
    /// Unique identifier (UUID string).
    public let id: String

    /// The entry title.
    public let title: String

    /// Rich-text body content (HTML or Markdown depending on workspace config).
    public let body: String?

    /// ISO-8601 timestamp of when the entry was published.
    public let publishedAt: String?

    /// Optional URL to the cover image.
    public let coverImageURL: String?

    /// URL-friendly slug for deep linking.
    public let urlSlug: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case publishedAt = "published_at"
        case coverImageURL = "cover_image_url"
        case urlSlug = "url_slug"
    }
}
