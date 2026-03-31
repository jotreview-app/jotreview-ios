import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Cross-Platform Colors (Changelog)

@available(iOS 15.0, macOS 12.0, *)
private enum ChangelogPlatformColor {
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
}

// MARK: - View Model

@available(iOS 15.0, macOS 12.0, *)
@MainActor
internal final class ChangelogViewModel: ObservableObject {

    @Published var entries: [ChangelogEntry] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func loadEntries(config: JotReviewConfig) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await APIClient.shared.fetchChangelog(
                projectId: config.projectId,
                baseURL: config.baseURL
            )
            entries = fetched
        } catch {
            errorMessage = "Could not load changelog."
            entries = []
        }
    }
}

// MARK: - Changelog View

/// A scrollable list of published changelog entries with cover images, titles,
/// dates, and body previews.
///
/// Present via the `.jotReviewChangelog(isPresented:)` view modifier
/// or inside a `.sheet`.
@available(iOS 15.0, macOS 12.0, *)
public struct ChangelogView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ChangelogViewModel()

    private let config: JotReviewConfig

    public init() {
        self.config = JotReview.currentConfig ?? JotReviewConfig(projectId: "", baseURL: "")
    }

    public var body: some View {
        NavigationView {
            content
                .background(ChangelogPlatformColor.groupedBackground)
                .navigationTitle("What's New")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                            .foregroundColor(.secondary)
                    }
                }
                .task { await viewModel.loadEntries(config: config) }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.entries.isEmpty {
            loadingView
        } else if let error = viewModel.errorMessage, viewModel.entries.isEmpty {
            errorView(error)
        } else if viewModel.entries.isEmpty {
            emptyView
        } else {
            entriesList
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
                Task { await viewModel.loadEntries(config: config) }
            }
            .font(.subheadline.weight(.medium))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "newspaper")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No updates yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Entries List

    private var entriesList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.entries) { entry in
                    ChangelogEntryCard(entry: entry)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Entry Card

@available(iOS 15.0, macOS 12.0, *)
private struct ChangelogEntryCard: View {

    let entry: ChangelogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover image
            if let imageURL = entry.coverImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipped()

                    case .failure:
                        imagePlaceholder

                    case .empty:
                        ZStack {
                            imagePlaceholder
                            ProgressView()
                        }

                    @unknown default:
                        imagePlaceholder
                    }
                }
            }

            // Text content
            VStack(alignment: .leading, spacing: 8) {
                // Date
                if let publishedAt = entry.publishedAt {
                    Text(formattedDate(publishedAt))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                // Title
                Text(entry.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(3)

                // Body preview
                if let body = entry.body, !body.isEmpty {
                    Text(strippedHTML(body))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                        .lineSpacing(2)
                }
            }
            .padding(16)
        }
        .background(ChangelogPlatformColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Helpers

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.08))
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary.opacity(0.3))
            )
    }

    /// Attempts to parse an ISO-8601 date string into a readable format.
    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            return Self.displayFormatter.string(from: date)
        }
        // Retry without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: iso) {
            return Self.displayFormatter.string(from: date)
        }
        // Fall back to the raw string trimmed to date portion
        return String(iso.prefix(10))
    }

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// Strips basic HTML tags for a plain-text preview.
    private func strippedHTML(_ html: String) -> String {
        // Simple regex-based strip for common tags
        let stripped = html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")

        // Collapse multiple whitespace / newlines
        return stripped
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
