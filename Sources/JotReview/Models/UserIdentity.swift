import Foundation

/// Represents an identified user for feedback submissions and secure identity verification.
public struct UserIdentity: Codable, Sendable {
    /// External user identifier from the host app.
    public let id: String

    /// Optional email address.
    public let email: String?

    /// Optional first name.
    public let firstName: String?

    /// Optional last name.
    public let lastName: String?

    /// Optional avatar image URL.
    public let avatar: String?

    /// Optional HMAC-SHA256 signature for secure identity verification.
    /// Computed as `HMAC-SHA256(id, projectSecret)` expressed as a hex string.
    public let signature: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName
        case lastName
        case avatar
        case signature
    }

    public init(
        id: String,
        email: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        avatar: String? = nil,
        signature: String? = nil
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.avatar = avatar
        self.signature = signature
    }
}
