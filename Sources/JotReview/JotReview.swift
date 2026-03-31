import Foundation

/// The primary entry point for the JotReview iOS SDK.
///
/// `JotReview` is a singleton that manages SDK configuration, user identity,
/// and anonymous visitor tracking. Call `setup(projectId:)` once at app launch
/// (typically in your `AppDelegate` or `@main App` init), then use `identify()`
/// to associate a logged-in user.
///
/// ```swift
/// // In AppDelegate.application(_:didFinishLaunchingWithOptions:)
/// JotReview.setup(projectId: "your-project-id")
///
/// // After user logs in
/// JotReview.identify(userId: "usr_123", email: "user@example.com")
///
/// // Show feedback form
/// JotReview.showFeedback()
/// ```
public final class JotReview {

    /// Shared singleton instance.
    public static let shared = JotReview()

    private var config: JotReviewConfig?
    private var currentUser: UserIdentity?
    private var visitorId: String?

    private init() {}

    // MARK: - Setup

    /// Initialize the JotReview SDK with your project ID.
    ///
    /// This should be called once, early in your app lifecycle. It persists
    /// a stable anonymous visitor ID and fetches workspace configuration
    /// in the background.
    ///
    /// - Parameters:
    ///   - projectId: Your workspace's public project identifier.
    ///   - baseURL: The JotReview instance URL. Defaults to `https://go.jotreview.app`.
    public static func setup(projectId: String, baseURL: String = "https://go.jotreview.app") {
        shared.config = JotReviewConfig(projectId: projectId, baseURL: baseURL)
        shared.visitorId = VisitorIdStore.getOrCreate()

        // Fetch workspace config in background
        Task {
            do {
                let workspace = try await APIClient.shared.fetchInit(
                    projectId: projectId,
                    baseURL: baseURL
                )
                await MainActor.run {
                    shared.config?.workspace = workspace
                }
            } catch {
                print("[JotReview] Setup warning: Could not fetch workspace config: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - User Identity

    /// Identify the current user for attributed feedback submissions.
    ///
    /// Call this after your user logs in. If a `signature` is provided,
    /// the server will verify it using HMAC-SHA256 against the project secret.
    ///
    /// - Parameters:
    ///   - userId: The user's unique identifier in your system.
    ///   - email: Optional email address.
    ///   - firstName: Optional first name.
    ///   - lastName: Optional last name.
    ///   - avatar: Optional avatar image URL.
    ///   - signature: Optional HMAC-SHA256 hex digest for secure identity verification.
    public static func identify(
        userId: String,
        email: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        avatar: String? = nil,
        signature: String? = nil
    ) {
        shared.currentUser = UserIdentity(
            id: userId,
            email: email,
            firstName: firstName,
            lastName: lastName,
            avatar: avatar,
            signature: signature
        )
    }

    /// Clear the current user identity (e.g. on logout).
    ///
    /// Anonymous visitor ID is preserved so vote history remains consistent.
    public static func logout() {
        shared.currentUser = nil
    }

    // MARK: - Feedback Presentation

    /// Present the feedback form as a modal sheet.
    ///
    /// On iOS this finds the topmost view controller and presents a
    /// `UIHostingController` wrapping the SwiftUI feedback form.
    ///
    /// - Parameter board: Optional board slug to pre-select. If `nil`, the
    ///   default public board is used.
    @MainActor
    public static func showFeedback(board: String? = nil) {
        guard let config = shared.config else {
            print("[JotReview] Call JotReview.setup() before showFeedback()")
            return
        }
        JotReviewPresenter.presentFeedback(config: config, user: shared.currentUser, board: board)
    }

    // MARK: - Internal Accessors

    /// Current SDK configuration, if setup has been called.
    internal static var currentConfig: JotReviewConfig? { shared.config }

    /// Current identified user, if any.
    internal static var currentUserIdentity: UserIdentity? { shared.currentUser }

    /// Stable anonymous visitor identifier for vote attribution.
    internal static var currentVisitorId: String? { shared.visitorId }
}
