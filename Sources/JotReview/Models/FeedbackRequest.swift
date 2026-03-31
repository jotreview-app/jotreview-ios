import Foundation

/// A single feedback request returned by the `/api/widget/v1/requests` endpoint.
public struct FeedbackRequest: Codable, Identifiable, Sendable {
    /// Unique identifier (UUID string).
    public let id: String

    /// The feedback title.
    public let title: String

    /// Optional rich-text description body.
    public let description: String?

    /// Current status — one of: pending, reviewing, planned, in_progress, completed, closed.
    public let status: String

    /// Number of votes this request has received.
    public let voteCount: Int

    /// ISO-8601 timestamp of when the request was created.
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case status
        case voteCount = "vote_count"
        case createdAt = "created_at"
    }
}
