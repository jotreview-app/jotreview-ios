import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Bridges SwiftUI feedback views into UIKit by finding the topmost
/// view controller and presenting a `UIHostingController`.
///
/// This is used internally by `JotReview.showFeedback()` so that
/// UIKit-based apps can present the feedback sheet without SwiftUI boilerplate.
/// SwiftUI apps should prefer the `.jotReviewFeedback(isPresented:board:)`
/// view modifier instead.
internal enum JotReviewPresenter {

    // MARK: - Present Feedback

    /// Presents the feedback sheet modally from the topmost view controller.
    ///
    /// - Parameters:
    ///   - config: The current SDK configuration.
    ///   - user: The identified user, or `nil` for anonymous submissions.
    ///   - board: Optional board slug to pre-select.
    @MainActor
    static func presentFeedback(config: JotReviewConfig, user: UserIdentity?, board: String?) {
        #if canImport(UIKit) && !os(watchOS)
        guard let rootVC = topMostViewController() else {
            print("[JotReview] Could not find a root view controller to present from.")
            return
        }

        if #available(iOS 15.0, *) {
            let sheet = FeedbackSheet(board: board)
            let hostingController = UIHostingController(rootView: sheet)
            hostingController.modalPresentationStyle = .pageSheet
            rootVC.present(hostingController, animated: true)
        } else {
            print("[JotReview] FeedbackSheet requires iOS 15.0+.")
        }
        #else
        print("[JotReview] showFeedback() is only supported on iOS.")
        _ = (config, user, board)
        #endif
    }

    // MARK: - Present Roadmap

    /// Presents the roadmap view modally from the topmost view controller.
    ///
    /// - Parameter config: The current SDK configuration.
    @MainActor
    static func presentRoadmap(config: JotReviewConfig) {
        #if canImport(UIKit) && !os(watchOS)
        guard let rootVC = topMostViewController() else {
            print("[JotReview] Could not find a root view controller to present from.")
            return
        }

        if #available(iOS 15.0, *) {
            let roadmap = RoadmapView()
            let hostingController = UIHostingController(rootView: roadmap)
            hostingController.modalPresentationStyle = .pageSheet
            rootVC.present(hostingController, animated: true)
        } else {
            print("[JotReview] RoadmapView requires iOS 15.0+.")
        }
        #else
        print("[JotReview] showRoadmap() is only supported on iOS.")
        _ = config
        #endif
    }

    // MARK: - Present Changelog

    /// Presents the changelog view modally from the topmost view controller.
    ///
    /// - Parameter config: The current SDK configuration.
    @MainActor
    static func presentChangelog(config: JotReviewConfig) {
        #if canImport(UIKit) && !os(watchOS)
        guard let rootVC = topMostViewController() else {
            print("[JotReview] Could not find a root view controller to present from.")
            return
        }

        if #available(iOS 15.0, *) {
            let changelog = ChangelogView()
            let hostingController = UIHostingController(rootView: changelog)
            hostingController.modalPresentationStyle = .pageSheet
            rootVC.present(hostingController, animated: true)
        } else {
            print("[JotReview] ChangelogView requires iOS 15.0+.")
        }
        #else
        print("[JotReview] showChangelog() is only supported on iOS.")
        _ = config
        #endif
    }

    // MARK: - Top View Controller

    #if canImport(UIKit) && !os(watchOS)
    /// Walks the view controller hierarchy to find the topmost presented controller.
    @MainActor
    private static func topMostViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        return rootVC.topMostPresentedViewController
    }
    #endif
}

// MARK: - UIViewController Helpers

#if canImport(UIKit) && !os(watchOS)
extension UIViewController {

    /// Traverses the presentation chain to find the topmost presented view controller.
    var topMostPresentedViewController: UIViewController {
        if let presented = presentedViewController {
            return presented.topMostPresentedViewController
        }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController {
            return visible.topMostPresentedViewController
        }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
            return selected.topMostPresentedViewController
        }
        return self
    }
}
#endif
