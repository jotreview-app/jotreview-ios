import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Cross-Platform Colors

/// Thin wrappers that resolve to UIKit adaptive colors on iOS and neutral
/// SwiftUI equivalents on macOS so the same view code compiles everywhere.
@available(iOS 15.0, macOS 12.0, *)
private enum PlatformColor {
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

    static var separator: Color {
        #if canImport(UIKit) && !os(watchOS)
        return Color(UIColor.separator)
        #else
        return Color(nsColor: .separatorColor)
        #endif
    }

    static var tertiaryFill: Color {
        #if canImport(UIKit) && !os(watchOS)
        return Color(UIColor.systemGray6)
        #else
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }
}

// MARK: - Submit State

@available(iOS 15.0, macOS 12.0, *)
internal enum SubmitState: Equatable {
    case idle
    case submitting
    case success
    case error(String)
}

// MARK: - View Model

@available(iOS 15.0, macOS 12.0, *)
@MainActor
internal final class FeedbackViewModel: ObservableObject {

    @Published var requests: [FeedbackRequest] = []
    @Published var isLoading: Bool = false
    @Published var submitState: SubmitState = .idle

    // MARK: - Load Requests

    func loadRequests(config: JotReviewConfig) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await APIClient.shared.fetchRequests(
                projectId: config.projectId,
                baseURL: config.baseURL
            )
            requests = fetched
        } catch {
            // Silently degrade — the list stays empty
            requests = []
        }
    }

    // MARK: - Submit Feedback

    func submit(
        title: String,
        description: String?,
        attachmentUrls: [String],
        board: String?,
        config: JotReviewConfig,
        user: UserIdentity?
    ) async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            submitState = .error("Title is required.")
            return
        }
        submitState = .submitting

        do {
            let submitData = SubmitData(
                projectId: config.projectId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
                attachmentUrls: attachmentUrls.isEmpty ? nil : attachmentUrls,
                user: user
            )
            _ = try await APIClient.shared.submitFeedback(
                projectId: config.projectId,
                baseURL: config.baseURL,
                data: submitData
            )
            submitState = .success

            // Refresh the list so the new item appears
            await loadRequests(config: config)

            // Auto-reset after a short delay so the user can submit again
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if submitState == .success {
                submitState = .idle
            }
        } catch {
            submitState = .error(error.localizedDescription)
        }
    }

    // MARK: - Toggle Vote

    func toggleVote(requestId: String, config: JotReviewConfig) async {
        do {
            let response = try await APIClient.shared.toggleVote(
                projectId: config.projectId,
                baseURL: config.baseURL,
                requestId: requestId,
                visitorId: JotReview.currentVisitorId ?? VisitorIdStore.getOrCreate()
            )
            // Update the local model with the new vote count
            if let index = requests.firstIndex(where: { $0.id == requestId }) {
                requests[index] = requests[index].withUpdatedVoteCount(response.voteCount)
            }
        } catch {
            // Vote failed silently — the count stays unchanged
        }
    }
}

// MARK: - Feedback Sheet

/// A SwiftUI sheet that lets users submit new feedback and browse existing requests.
///
/// Present via the `.jotReviewFeedback(isPresented:board:)` view modifier
/// or directly inside a `.sheet`.
///
/// ```swift
/// .sheet(isPresented: $showFeedback) {
///     FeedbackSheet(board: "features")
/// }
/// ```
@available(iOS 15.0, macOS 12.0, *)
public struct FeedbackSheet: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FeedbackViewModel()

    @State private var title: String = ""
    @State private var descriptionText: String = ""
    @State private var attachmentUrls: [String] = []

    let config: JotReviewConfig
    let user: UserIdentity?
    let board: String?

    // MARK: - Initializer

    public init(board: String? = nil) {
        self.config = JotReview.currentConfig ?? JotReviewConfig(projectId: "", baseURL: "")
        self.user = JotReview.currentUserIdentity
        self.board = board
    }

    // MARK: - Body

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    submitFormSection
                    divider
                    existingRequestsSection
                    poweredByFooter
                }
            }
            .background(PlatformColor.groupedBackground)
            .navigationTitle("Send Feedback")
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

    // MARK: - Submit Form

    private var submitFormSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title field
            VStack(alignment: .leading, spacing: 6) {
                Text("Title")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                TextField("What's your feedback?", text: $title)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(PlatformColor.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(PlatformColor.separator.opacity(0.5), lineWidth: 1)
                    )
            }

            // Description field
            VStack(alignment: .leading, spacing: 6) {
                Text("Details")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                TextEditor(text: $descriptionText)
                    .frame(minHeight: 80, maxHeight: 160)
                    .padding(8)
                    .background(PlatformColor.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(PlatformColor.separator.opacity(0.5), lineWidth: 1)
                    )
            }

            // Image attachments (PRO+ feature)
            if config.imageAttachmentsEnabled {
                ImageAttachmentView(
                    projectId: config.projectId,
                    baseURL: config.baseURL,
                    urls: $attachmentUrls
                )
            }

            // Submit button + state
            submitButton

            // Error / success message
            submitStateMessage
        }
        .padding(16)
    }

    @ViewBuilder
    private var submitButton: some View {
        let isDisabled = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || viewModel.submitState == .submitting

        Button {
            Task {
                let desc = descriptionText.isEmpty ? nil : descriptionText
                await viewModel.submit(
                    title: title,
                    description: desc,
                    attachmentUrls: attachmentUrls,
                    board: board,
                    config: config,
                    user: user
                )
                if viewModel.submitState == .success {
                    title = ""
                    descriptionText = ""
                    attachmentUrls = []
                }
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.submitState == .submitting {
                    ProgressView()
                        #if os(iOS)
                        .tint(.white)
                        #endif
                }
                Text(viewModel.submitState == .submitting ? "Submitting..." : "Submit Feedback")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isDisabled ? Color.gray.opacity(0.4) : Color.accentColor)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .disabled(isDisabled)
    }

    @ViewBuilder
    private var submitStateMessage: some View {
        switch viewModel.submitState {
        case .success:
            Label("Feedback submitted!", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundColor(.green)
                .transition(.opacity)

        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundColor(.red)
                .transition(.opacity)

        default:
            EmptyView()
        }
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(PlatformColor.separator.opacity(0.3))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    // MARK: - Existing Requests

    private var existingRequestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Existing Feedback")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            if viewModel.isLoading && viewModel.requests.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 32)
                    Spacer()
                }
            } else if viewModel.requests.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No feedback yet. Be the first!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.requests) { request in
                        FeedbackRequestRow(
                            request: request,
                            onVote: {
                                Task {
                                    await viewModel.toggleVote(requestId: request.id, config: config)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Powered By Footer

    private var poweredByFooter: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("Powered by")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.5))
            Text("JotReview")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Text("v\(JotReviewVersion.current)")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.35))
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Feedback Request Row

@available(iOS 15.0, macOS 12.0, *)
internal struct FeedbackRequestRow: View {

    let request: FeedbackRequest
    let onVote: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Vote button
            voteButton

            // Content
            VStack(alignment: .leading, spacing: 4) {
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

                StatusBadge(status: request.status)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(PlatformColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var voteButton: some View {
        Button(action: onVote) {
            VStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .bold))
                Text("\(request.voteCount)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.secondary)
            .frame(width: 40, height: 44)
            .background(PlatformColor.tertiaryFill)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FeedbackRequest Helpers

extension FeedbackRequest {
    /// Returns a JSON-decoded copy of this request with an updated vote count.
    ///
    /// We re-encode/decode via JSON to avoid conflicting with the synthesized
    /// memberwise initializer that `Codable` structs with `let` properties get.
    internal func withUpdatedVoteCount(_ newCount: Int) -> FeedbackRequest {
        var dict: [String: Any] = [
            "id": id,
            "title": title,
            "status": status,
            "vote_count": newCount,
        ]
        if let d = description { dict["description"] = d }
        if let c = createdAt { dict["created_at"] = c }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let updated = try? JSONDecoder().decode(FeedbackRequest.self, from: data)
        else { return self }
        return updated
    }
}
