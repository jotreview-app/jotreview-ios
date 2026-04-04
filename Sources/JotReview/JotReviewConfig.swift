import Foundation

/// Internal configuration holder populated during `JotReview.setup()`.
internal struct JotReviewConfig {
    /// The public project identifier used to authenticate API requests.
    let projectId: String

    /// Base URL of the JotReview instance (e.g. "https://go.jotreview.app").
    let baseURL: String

    /// Workspace display info fetched asynchronously after setup.
    var workspace: WorkspaceInfo?

    /// Whether the workspace plan supports image attachments (PRO+ feature).
    var imageAttachmentsEnabled: Bool = false
}
