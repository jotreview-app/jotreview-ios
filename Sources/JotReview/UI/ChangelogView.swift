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
            .toolbarBackground(.visible, for: .navigationBar)
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

#if canImport(UIKit) && !os(watchOS)

/// SwiftUI wrapper that renders HTML using a self-sizing `UITextView`.
/// Leverages `UIViewRepresentable.sizeThatFits` (iOS 16+) so SwiftUI
/// provides the correct proposed width — no GeometryReader or manual
/// height Bindings needed.
@available(iOS 15.0, *)
private struct RichHTMLText: View {

    let html: String

    var body: some View {
        HTMLTextViewRepresentable(html: html)
    }
}

@available(iOS 15.0, *)
private struct HTMLTextViewRepresentable: UIViewRepresentable {

    let html: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var renderedHTML: String?
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        guard context.coordinator.renderedHTML != html else { return }
        context.coordinator.renderedHTML = html

        let styledHTML = """
        <html>
        <head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {
                font-family: -apple-system, system-ui;
                font-size: 16px;
                line-height: 1.5;
                color: #1c1c1e;
                margin: 0;
                padding: 0;
            }
            h1, h2, h3, h4 {
                font-weight: 700;
                margin-top: 16px;
                margin-bottom: 6px;
            }
            h1 { font-size: 22px; }
            h2 { font-size: 19px; }
            h3 { font-size: 17px; }
            p { margin-top: 0; margin-bottom: 10px; }
            ul, ol {
                padding-left: 24px;
                margin-top: 4px;
                margin-bottom: 10px;
            }
            li {
                margin-bottom: 6px;
            }
        </style></head>
        <body>\(html)</body>
        </html>
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
        else { return }

        // Post-process: clamp paragraph spacing that NSAttributedString's
        // HTML parser adds on top of CSS margins (causes excessive gaps).
        let mutable = NSMutableAttributedString(attributedString: nsAttr)
        mutable.enumerateAttribute(
            .paragraphStyle,
            in: NSRange(location: 0, length: mutable.length)
        ) { value, range, _ in
            guard let style = value as? NSParagraphStyle else { return }
            let newStyle = style.mutableCopy() as! NSMutableParagraphStyle
            newStyle.paragraphSpacing = min(style.paragraphSpacing, 6)
            newStyle.paragraphSpacingBefore = min(style.paragraphSpacingBefore, 2)
            mutable.addAttribute(.paragraphStyle, value: newStyle, range: range)
        }

        textView.attributedText = mutable
        textView.invalidateIntrinsicContentSize()
    }

    // iOS 16+: SwiftUI calls this with the actual proposed width from layout,
    // so height calculation uses the correct width — no manual measurement needed.
    @available(iOS 16.0, macOS 13.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        return uiView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    }
}

#else

/// macOS fallback — uses SwiftUI Text with AttributedString.
@available(macOS 12.0, *)
private struct RichHTMLText: View {

    let html: String
    @State private var attributedText: AttributedString?

    var body: some View {
        if let attributedText {
            Text(attributedText)
                .font(.body)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .task {
                    let styledHTML = "<html><head><style>body{font-family:-apple-system;font-size:14px;line-height:1.5;}h1,h2,h3{font-weight:700;}ul,ol{padding-left:20px;}li{margin-bottom:2px;}</style></head><body>\(html)</body></html>"
                    guard let data = styledHTML.data(using: .utf8),
                          let nsAttr = try? NSAttributedString(
                            data: data,
                            options: [.documentType: NSAttributedString.DocumentType.html,
                                      .characterEncoding: String.Encoding.utf8.rawValue],
                            documentAttributes: nil
                          )
                    else { return }
                    attributedText = try? AttributedString(nsAttr, including: \.appKit)
                }
        }
    }
}

#endif

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
}
