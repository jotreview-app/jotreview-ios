import Foundation

/// Payload sent to the `/api/widget/v1/submit` endpoint when creating a new feedback request.
internal struct SubmitData: Encodable {
    let projectId: String
    let title: String
    let description: String?
    let user: SubmitUser?

    /// Nested user identity sent alongside the submission.
    struct SubmitUser: Encodable {
        let id: String?
        let email: String?
        let firstName: String?
        let lastName: String?
        let avatar: String?
        let signature: String?
    }

    /// Convenience initializer that maps from a `UserIdentity`.
    init(projectId: String, title: String, description: String?, user: UserIdentity?) {
        self.projectId = projectId
        self.title = title
        self.description = description
        self.user = user.map { identity in
            SubmitUser(
                id: identity.id,
                email: identity.email,
                firstName: identity.firstName,
                lastName: identity.lastName,
                avatar: identity.avatar,
                signature: identity.signature
            )
        }
    }
}

/// Response from a successful feedback submission.
internal struct SubmitResponse: Decodable {
    let success: Bool
    let requestId: String
}

/// Response from a successful vote toggle.
internal struct VoteResponse: Decodable {
    let success: Bool
    let voted: Bool
    let voteCount: Int

    enum CodingKeys: String, CodingKey {
        case success
        case voted
        case voteCount = "vote_count"
    }
}
