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
                .navigationBarTitleDisplayMode(.large)
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

    @State private var selectedEntry: ChangelogEntry?
    @Namespace private var zoomNamespace

    private var entriesList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.entries) { entry in
                    ChangelogEntryCard(entry: entry)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedEntry = entry }
                        .applyMatchedSource(id: entry.id, in: zoomNamespace)
                }
            }
            .padding(16)
        }
        .sheet(item: $selectedEntry) { entry in
            ChangelogDetailView(entry: entry)
                .applyZoomTransition(sourceID: entry.id, in: zoomNamespace)
        }
    }
}

// MARK: - Detail View

@available(iOS 15.0, macOS 12.0, *)
internal struct ChangelogDetailView: View {

    @Environment(\.dismiss) private var dismiss
    let entry: ChangelogEntry

    var body: some View {
        detailNavigation {
            ScrollView {
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
                                    .frame(height: 220)
                                    .clipped()
                            case .failure:
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.08))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 220)
                            case .empty:
                                ZStack {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.08))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 220)
                                    ProgressView()
                                }
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        // Date
                        if let publishedAt = entry.publishedAt {
                            Text(formattedDate(publishedAt))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }

                        // Title
                        Text(entry.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        // Full body (rendered as rich text from HTML)
                        if let body = entry.body, !body.isEmpty {
                            RichHTMLText(html: body)
                        }
                    }
                    .padding(20)
                }
            }
            .background(ChangelogPlatformColor.groupedBackground)
            .navigationTitle("Update")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .applyVisibleToolbarBackground()
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    /// Use NavigationStack on iOS 16+ (fixes sheet insets on iOS 26),
    /// fall back to NavigationView on iOS 15.
    @ViewBuilder
    private func detailNavigation<C: View>(@ViewBuilder content: () -> C) -> some View {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            NavigationStack { content() }
        } else {
            NavigationView { content() }.navigationViewStyle(.stack)
        }
        #else
        NavigationView { content() }
        #endif
    }

    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            return Self.displayFormatter.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: iso) {
            return Self.displayFormatter.string(from: date)
        }
        return String(iso.prefix(10))
    }

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

}

// MARK: - Rich HTML Text Renderer
//
// Pure SwiftUI approach: pre-process HTML to convert <li> to bullet text,
// then render with NSAttributedString → AttributedString → SwiftUI Text.
// No UITextView — avoids all iOS 26 sizing/blank-view issues.

@available(iOS 15.0, macOS 12.0, *)
private struct RichHTMLText: View {

    let html: String
    @State private var attributedText: AttributedString?

    var body: some View {
        Group {
            if let attributedText {
                Text(attributedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
            }
        }
        .task { attributedText = Self.render(html) }
    }

    /// Converts HTML to a styled AttributedString suitable for SwiftUI Text.
    /// Pre-processes list items into bullet text so NSAttributedString doesn't
    /// need to handle NSTextList (which SwiftUI Text drops).
    @MainActor
    static func render(_ html: String) -> AttributedString? {
        // Convert <li> to paragraphs with bullet character.
        // This avoids NSTextList which SwiftUI Text can't render.
        var processed = html
        // Remove list wrappers
        processed = processed.replacingOccurrences(
            of: "</?[uo]l[^>]*>", with: "", options: .regularExpression)
        // Convert list items to bullet paragraphs
        processed = processed.replacingOccurrences(
            of: "<li[^>]*>", with: "<p class=\"li\">\u{2022}  ", options: .regularExpression)
        processed = processed.replacingOccurrences(of: "</li>", with: "</p>")

        let styledHTML = """
        <html><head>
        <style>
            body {
                font-family: -apple-system, system-ui;
                font-size: 16px;
                line-height: 1.5;
                color: #1c1c1e;
                margin: 0; padding: 0;
            }
            h1, h2, h3, h4 { font-weight: 700; margin-top: 14px; margin-bottom: 4px; }
            h1 { font-size: 22px; } h2 { font-size: 19px; } h3 { font-size: 17px; }
            p { margin: 0 0 6px 0; }
            p.li { margin: 0 0 4px 20px; }
        </style>
        </head><body>\(processed)</body></html>
        """

        guard let data = styledHTML.data(using: .utf8),
              let nsAttr = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              )
        else { return nil }

        // Clamp paragraph spacing the HTML parser adds on top of CSS.
        let mutable = NSMutableAttributedString(attributedString: nsAttr)
        mutable.enumerateAttribute(
            .paragraphStyle, in: NSRange(location: 0, length: mutable.length)
        ) { value, range, _ in
            guard let style = value as? NSParagraphStyle else { return }
            let s = style.mutableCopy() as! NSMutableParagraphStyle
            s.paragraphSpacing = min(style.paragraphSpacing, 4)
            s.paragraphSpacingBefore = 0
            mutable.addAttribute(.paragraphStyle, value: s, range: range)
        }

        #if canImport(UIKit)
        return try? AttributedString(mutable, including: \.uiKit)
        #else
        return try? AttributedString(mutable, including: \.appKit)
        #endif
    }
}

// MARK: - Entry Card

@available(iOS 15.0, macOS 12.0, *)
internal struct ChangelogEntryCard: View {

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

// MARK: - Zoom Transition Helpers (iOS 18+, graceful fallback)

@available(iOS 15.0, macOS 12.0, *)
private extension View {
    /// Marks this view as the source of a zoom transition on iOS 18+. No-op on older versions.
    @ViewBuilder
    func applyMatchedSource(id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Applies a zoom navigation transition on iOS 18+. No-op on older versions and macOS.
    @ViewBuilder
    func applyZoomTransition(sourceID: String, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Makes the navigation bar background visible on iOS 16+. No-op on older versions.
    @ViewBuilder
    func applyVisibleToolbarBackground() -> some View {
        if #available(iOS 16.0, *) {
            self.toolbarBackground(.visible, for: .navigationBar)
        } else {
            self
        }
    }
}
