import SwiftUI

// MARK: - JotReview View Modifiers

@available(iOS 15.0, macOS 12.0, *)
extension View {

    /// Presents the JotReview feedback sheet as a modal.
    ///
    /// The sheet includes a submission form at the top and a scrollable list
    /// of existing feedback with vote counts below.
    ///
    /// ```swift
    /// struct ContentView: View {
    ///     @State private var showFeedback = false
    ///
    ///     var body: some View {
    ///         Button("Feedback") { showFeedback = true }
    ///             .jotReviewFeedback(isPresented: $showFeedback, board: "features")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - isPresented: Binding that controls sheet visibility.
    ///   - board: Optional board slug to pre-select. Pass `nil` for the default board.
    /// - Returns: A view with the feedback sheet modifier applied.
    public func jotReviewFeedback(isPresented: Binding<Bool>, board: String? = nil) -> some View {
        self.sheet(isPresented: isPresented) {
            FeedbackSheet(board: board)
        }
    }

    /// Presents the JotReview roadmap as a modal sheet.
    ///
    /// The roadmap groups feedback requests into three columns:
    /// **In Progress**, **Planned**, and **Under Review**.
    ///
    /// ```swift
    /// struct ContentView: View {
    ///     @State private var showRoadmap = false
    ///
    ///     var body: some View {
    ///         Button("Roadmap") { showRoadmap = true }
    ///             .jotReviewRoadmap(isPresented: $showRoadmap)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter isPresented: Binding that controls sheet visibility.
    /// - Returns: A view with the roadmap sheet modifier applied.
    public func jotReviewRoadmap(isPresented: Binding<Bool>) -> some View {
        self.sheet(isPresented: isPresented) {
            RoadmapView()
        }
    }

    /// Presents the JotReview changelog as a modal sheet.
    ///
    /// Shows a scrollable list of published changelog entries with cover images,
    /// titles, dates, and body previews.
    ///
    /// ```swift
    /// struct ContentView: View {
    ///     @State private var showChangelog = false
    ///
    ///     var body: some View {
    ///         Button("What's New") { showChangelog = true }
    ///             .jotReviewChangelog(isPresented: $showChangelog)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter isPresented: Binding that controls sheet visibility.
    /// - Returns: A view with the changelog sheet modifier applied.
    public func jotReviewChangelog(isPresented: Binding<Bool>) -> some View {
        self.sheet(isPresented: isPresented) {
            ChangelogView()
        }
    }
}
