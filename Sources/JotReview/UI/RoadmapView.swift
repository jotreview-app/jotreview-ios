import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Cross-Platform Colors (Roadmap)

@available(iOS 15.0, macOS 12.0, *)
fileprivate enum RoadmapPlatformColor {
    static var groupedBackground: Color {
        #if canImport(UIKit) && !os(watchOS)
        return Color(UIColor.systemGroupedBackground)
        #else
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var cardBackground: Color {
        #if canImport(UIKit) && !os(watchOS)
        return Color(UIColor.systemBackground)
        #else
        return Color(nsColor: .textBackgroundColor)
        #endif
    }

    static var badgeFill: Color {
        #if canImport(UIKit) && !os(watchOS)
        return Color(UIColor.systemGray5)
        #else
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
}

// MARK: - Roadmap Column Definition

@available(iOS 15.0, macOS 12.0, *)
internal struct RoadmapColumn: Identifiable {
    let id: String
    let title: String
    let statuses: Set<String>
    let accentColor: Color

    var requests: [FeedbackRequest] = []
}

// MARK: - View Model

@available(iOS 15.0, macOS 12.0, *)
@MainActor
internal final class RoadmapViewModel: ObservableObject {

    @Published var columns: [RoadmapColumn] = RoadmapViewModel.defaultColumns
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private static var defaultColumns: [RoadmapColumn] {
        [
            RoadmapColumn(
                id: "in_progress",
                title: "In Progress",
                statuses: ["in_progress"],
                accentColor: Color(red: 0.0, green: 0.31, blue: 0.67)
            ),
            RoadmapColumn(
                id: "planned",
                title: "Planned",
                statuses: ["planned"],
                accentColor: .blue
            ),
            RoadmapColumn(
                id: "reviewing",
                title: "Under Review",
                statuses: ["reviewing"],
                accentColor: .orange
            ),
        ]
    }

    func loadRequests(config: JotReviewConfig) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await APIClient.shared.fetchRequests(
                projectId: config.projectId,
                baseURL: config.baseURL
            )

            // Group requests into columns by status
            var updated = RoadmapViewModel.defaultColumns
            for i in updated.indices {
                updated[i].requests = fetched
                    .filter { updated[i].statuses.contains($0.status.lowercased()) }
                    .sorted { $0.voteCount > $1.voteCount }
            }
            columns = updated
        } catch {
            errorMessage = "Could not load roadmap."
            columns = RoadmapViewModel.defaultColumns
        }
    }
}

// MARK: - Roadmap View

/// A 3-column roadmap showing feedback requests grouped by status:
/// **In Progress**, **Planned**, and **Under Review**.
///
/// Present via the `.jotReviewRoadmap(isPresented:)` view modifier
/// or inside a `.sheet`.
@available(iOS 15.0, macOS 12.0, *)
public struct RoadmapView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RoadmapViewModel()

    private let config: JotReviewConfig
    private let user: UserIdentity?

    public init() {
        self.config = JotReview.currentConfig ?? JotReviewConfig(projectId: "", baseURL: "")
        self.user = JotReview.currentUserIdentity
    }

    public var body: some View {
        NavigationView {
            content
                .background(RoadmapPlatformColor.groupedBackground)
                .navigationTitle("Roadmap")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                            .foregroundColor(.secondary)
                    }
                }
                .task { await viewModel.loadRequests(config: config) }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.columns.allSatisfy({ $0.requests.isEmpty }) {
            loadingView
        } else if let error = viewModel.errorMessage, viewModel.columns.allSatisfy({ $0.requests.isEmpty }) {
            errorView(error)
        } else {
            columnsView
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Retry") {
                Task { await viewModel.loadRequests(config: config) }
            }
            .font(.subheadline.weight(.medium))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Columns Layout

    private var columnsView: some View {
        ScrollView {
            #if os(iOS)
            // On iOS: vertical stacked columns (phones) or horizontal (iPad)
            VStack(spacing: 20) {
                ForEach(viewModel.columns) { column in
                    RoadmapColumnView(column: column)
                }
            }
            .padding(16)
            #else
            // On macOS: horizontal layout
            HStack(alignment: .top, spacing: 16) {
                ForEach(viewModel.columns) { column in
                    RoadmapColumnView(column: column)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            #endif
        }
    }
}

// MARK: - Column View

@available(iOS 15.0, macOS 12.0, *)
private struct RoadmapColumnView: View {

    let column: RoadmapColumn

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(column.accentColor)
                    .frame(width: 8, height: 8)

                Text(column.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("\(column.requests.count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoadmapPlatformColor.badgeFill)
                    .clipShape(Capsule())

                Spacer()
            }
            .padding(.bottom, 4)

            if column.requests.isEmpty {
                emptyColumnPlaceholder
            } else {
                ForEach(column.requests) { request in
                    RoadmapRequestCard(request: request)
                }
            }
        }
    }

    private var emptyColumnPlaceholder: some View {
        Text("No items")
            .font(.caption)
            .foregroundColor(.secondary.opacity(0.6))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(RoadmapPlatformColor.cardBackground.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Request Card

@available(iOS 15.0, macOS 12.0, *)
private struct RoadmapRequestCard: View {

    let request: FeedbackRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(request.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)

            if let description = request.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                // Vote count
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(request.voteCount)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                }
                .foregroundColor(.secondary)

                StatusBadge(status: request.status)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoadmapPlatformColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
