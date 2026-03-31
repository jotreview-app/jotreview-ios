import SwiftUI

/// A small colored badge that reflects a feedback request's status.
///
/// Colors adapt to light/dark mode using system tints and map to the
/// JotReview canonical status set: pending, reviewing, planned,
/// in_progress, completed, closed.
@available(iOS 15.0, macOS 12.0, *)
public struct StatusBadge: View {

    /// Raw status string from the API (e.g. "in_progress").
    public let status: String

    public init(status: String) {
        self.status = status
    }

    // MARK: - Body

    public var body: some View {
        Text(displayLabel)
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .modifier(TrackingModifier(value: 0.4))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Helpers

    private var displayLabel: String {
        switch status.lowercased() {
        case "pending":      return "Pending"
        case "reviewing":    return "Reviewing"
        case "planned":      return "Planned"
        case "in_progress":  return "In Progress"
        case "completed":    return "Completed"
        case "closed":       return "Closed"
        default:             return status.capitalized
        }
    }

    private var backgroundColor: Color {
        switch status.lowercased() {
        case "pending":      return Color.orange.opacity(0.15)
        case "reviewing":    return Color.orange.opacity(0.15)
        case "planned":      return Color.blue.opacity(0.15)
        case "in_progress":  return Color(red: 0.0, green: 0.31, blue: 0.67).opacity(0.15)
        case "completed":    return Color.brown.opacity(0.15)
        case "closed":       return Color.gray.opacity(0.12)
        default:             return Color.gray.opacity(0.12)
        }
    }

    private var foregroundColor: Color {
        switch status.lowercased() {
        case "pending":      return Color.orange
        case "reviewing":    return Color.orange
        case "planned":      return Color.blue
        case "in_progress":  return Color(red: 0.0, green: 0.31, blue: 0.67)
        case "completed":    return Color.brown
        case "closed":       return Color.gray
        default:             return Color.gray
        }
    }
}

// MARK: - Tracking Modifier (availability-gated)

/// Applies `.tracking()` on macOS 13+ / iOS 16+ and is a no-op on older OS versions.
@available(iOS 15.0, macOS 12.0, *)
private struct TrackingModifier: ViewModifier {
    let value: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 13.0, iOS 16.0, *) {
            content.tracking(value)
        } else {
            content
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 15.0, macOS 12.0, *)
struct StatusBadge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            StatusBadge(status: "pending")
            StatusBadge(status: "reviewing")
            StatusBadge(status: "planned")
            StatusBadge(status: "in_progress")
            StatusBadge(status: "completed")
            StatusBadge(status: "closed")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
