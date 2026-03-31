import Foundation

/// Internal configuration holder populated during `JotReview.setup()`.
internal struct JotReviewConfig {
    /// The public project identifier used to authenticate API requests.
    let projectId: String

    /// Base URL of the JotReview instance (e.g. "https://jotreview.app").
    let baseURL: String

    /// Workspace display info fetched asynchronously after setup.
    var workspace: WorkspaceInfo?
}
