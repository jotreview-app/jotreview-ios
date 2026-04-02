#if DEBUG
import SwiftUI

// MARK: - Sample Data

@available(iOS 15.0, macOS 12.0, *)
internal enum ChangelogSampleData {

    /// A realistic changelog entry matching the "User Empowerment & Access Fixes" post.
    /// HTML body includes headings, paragraphs, bold text, bullet lists, and emoji.
    static let userEmpowermentEntry = ChangelogEntry(
        id: "preview-001",
        title: "User Empowerment & Access Fixes \u{1F512}",
        body: """
        <h2>Acting like a user just got easier \u{1F464}</h2>
        <p>We realized some of you were stuck behind a wall where you couldn't actually "be" a user. It was a major headache (and we're sorry about that), but we've cleared the path so you can finally interact with the platform exactly as intended.</p>
        <p><strong>What's fixed:</strong></p>
        <ul>
        <li>Fixed a critical permission bug that prevented administrative accounts from toggling into "User View" mode.</li>
        <li>Resolved an issue where user-specific actions were grayed out even when permissions were correctly assigned.</li>
        <li>Improved the session switching speed so you can jump between roles without the annoying "Loading\u{2026}" spinner hanging around.</li>
        </ul>
        <p>No more workarounds or pretending\u{2014}now you can see and do exactly what your users see and do.</p>
        <h2>Bug Fixes \u{1FAB2}</h2>
        <ul>
        <li>Fixed the "infinite scroll" bug on the dashboard that felt more like an "infinite wait."</li>
        <li>Emojis in comments no longer transform into weird question marks in older browsers.</li>
        <li>Resolved a race condition in real-time notifications that occasionally showed duplicate alerts.</li>
        </ul>
        """,
        publishedAt: "2026-03-29T12:00:00Z",
        coverImageURL: "https://rgzqdcictkpwauncunma.supabase.co/storage/v1/object/public/public-assets/changelog/9eaf6a46-2dec-422c-adb2-ceed52261a81.jpeg?t=1774799743964",
        urlSlug: "user-empowerment-access-fixes"
    )

    /// A second entry with a different structure — shorter, with numbered list.
    static let roadmapUpdateEntry = ChangelogEntry(
        id: "preview-002",
        title: "Public Roadmap & Voting Improvements",
        body: """
        <h2>Your voice matters more now</h2>
        <p>We've revamped the public roadmap to make it easier to see what's coming and influence what gets built next.</p>
        <h3>What changed:</h3>
        <ol>
        <li><strong>New 3-column layout</strong> — Now, Next, and Exploring columns give you a clearer picture of priorities.</li>
        <li><strong>Vote counts are public</strong> — See how many people want the same thing you do.</li>
        <li><strong>Status auto-sync</strong> — When the team moves a request to "In Progress," the roadmap updates instantly.</li>
        </ol>
        <p>Head over to your board's <strong>Roadmap</strong> tab to check it out.</p>
        """,
        publishedAt: "2026-03-15T09:30:00Z",
        coverImageURL: nil,
        urlSlug: "roadmap-voting-improvements"
    )

    /// A third entry with cover image URL for testing image loading states.
    static let changelogAIEntry = ChangelogEntry(
        id: "preview-003",
        title: "AI-Powered Changelog Writing \u{2728}",
        body: """
        <p>Writing changelog entries just got a whole lot easier. Our new AI assistant lives right inside the editor and helps you communicate updates clearly.</p>
        <h2>Features</h2>
        <ul>
        <li><strong>Improve writing</strong> — Rewrites your draft for clarity and tone.</li>
        <li><strong>Add summary</strong> — Generates a TL;DR for long entries.</li>
        <li><strong>Fix formatting</strong> — Cleans up Markdown and HTML inconsistencies.</li>
        <li><strong>Suggest tags</strong> — Recommends appropriate tags based on content.</li>
        </ul>
        <p>The assistant uses your workspace context to match your team's voice and style.</p>
        """,
        publishedAt: "2026-02-20T15:00:00Z",
        coverImageURL: "https://images.unsplash.com/photo-1677442136019-21780ecad995?w=800&h=400&fit=crop",
        urlSlug: "ai-changelog-writing"
    )

    static let allEntries: [ChangelogEntry] = [
        userEmpowermentEntry,
        roadmapUpdateEntry,
        changelogAIEntry
    ]
}

// MARK: - Previews

@available(iOS 17.0, macOS 14.0, *)
#Preview("Changelog Detail — Rich HTML") {
    ChangelogDetailView(entry: ChangelogSampleData.userEmpowermentEntry)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Changelog Detail — Numbered List") {
    ChangelogDetailView(entry: ChangelogSampleData.roadmapUpdateEntry)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Changelog Detail — With Cover Image") {
    ChangelogDetailView(entry: ChangelogSampleData.changelogAIEntry)
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Changelog Card List") {
    NavigationView {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(ChangelogSampleData.allEntries) { entry in
                    ChangelogEntryCard(entry: entry)
                }
            }
            .padding(16)
        }
        .background(Color(white: 0.95))
        .navigationTitle("What's New")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("Single Card") {
    ChangelogEntryCard(entry: ChangelogSampleData.userEmpowermentEntry)
        .padding(16)
}

#endif
