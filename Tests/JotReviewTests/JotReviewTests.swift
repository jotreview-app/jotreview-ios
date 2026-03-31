import XCTest
@testable import JotReview

final class JotReviewTests: XCTestCase {

    // MARK: - VisitorIdStore

    func testVisitorIdStoreCreatesAndPersists() {
        VisitorIdStore.clear()
        let first = VisitorIdStore.getOrCreate()
        XCTAssertFalse(first.isEmpty, "Visitor ID should not be empty")

        let second = VisitorIdStore.getOrCreate()
        XCTAssertEqual(first, second, "Visitor ID should be stable across calls")
    }

    func testVisitorIdStoreClearResets() {
        let before = VisitorIdStore.getOrCreate()
        VisitorIdStore.clear()
        let after = VisitorIdStore.getOrCreate()
        XCTAssertNotEqual(before, after, "Visitor ID should change after clear")
    }

    // MARK: - Model Decoding

    func testWorkspaceInfoDecoding() throws {
        let json = """
        {
            "name": "Acme",
            "slug": "acme",
            "logo_url": "https://example.com/logo.png",
            "primary_color": "#005bc4",
            "theme": "light",
            "language": "en"
        }
        """
        let data = Data(json.utf8)
        let info = try JSONDecoder().decode(WorkspaceInfo.self, from: data)
        XCTAssertEqual(info.name, "Acme")
        XCTAssertEqual(info.slug, "acme")
        XCTAssertEqual(info.logoURL, "https://example.com/logo.png")
        XCTAssertEqual(info.primaryColor, "#005bc4")
        XCTAssertEqual(info.theme, "light")
        XCTAssertEqual(info.language, "en")
    }

    func testWorkspaceInfoDecodingWithNulls() throws {
        let json = """
        {
            "name": "Minimal",
            "slug": "minimal",
            "logo_url": null,
            "primary_color": null,
            "theme": null,
            "language": null
        }
        """
        let data = Data(json.utf8)
        let info = try JSONDecoder().decode(WorkspaceInfo.self, from: data)
        XCTAssertEqual(info.name, "Minimal")
        XCTAssertNil(info.logoURL)
        XCTAssertNil(info.primaryColor)
    }

    func testFeedbackRequestDecoding() throws {
        let json = """
        {
            "id": "abc-123",
            "title": "Add dark mode",
            "description": "Please add a dark theme option",
            "status": "planned",
            "vote_count": 42,
            "created_at": "2026-01-15T10:30:00Z"
        }
        """
        let data = Data(json.utf8)
        let request = try JSONDecoder().decode(FeedbackRequest.self, from: data)
        XCTAssertEqual(request.id, "abc-123")
        XCTAssertEqual(request.title, "Add dark mode")
        XCTAssertEqual(request.status, "planned")
        XCTAssertEqual(request.voteCount, 42)
        XCTAssertEqual(request.createdAt, "2026-01-15T10:30:00Z")
    }

    func testChangelogEntryDecoding() throws {
        let json = """
        {
            "id": "entry-1",
            "title": "Version 2.0 Released",
            "body": "<p>Big update!</p>",
            "published_at": "2026-03-01T12:00:00Z",
            "cover_image_url": "https://example.com/cover.jpg",
            "url_slug": "version-2-0-released"
        }
        """
        let data = Data(json.utf8)
        let entry = try JSONDecoder().decode(ChangelogEntry.self, from: data)
        XCTAssertEqual(entry.id, "entry-1")
        XCTAssertEqual(entry.title, "Version 2.0 Released")
        XCTAssertEqual(entry.publishedAt, "2026-03-01T12:00:00Z")
        XCTAssertEqual(entry.coverImageURL, "https://example.com/cover.jpg")
        XCTAssertEqual(entry.urlSlug, "version-2-0-released")
    }

    func testUserIdentityInit() {
        let user = UserIdentity(
            id: "usr_42",
            email: "test@example.com",
            firstName: "Jane",
            lastName: nil,
            avatar: nil,
            signature: "abc123"
        )
        XCTAssertEqual(user.id, "usr_42")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.firstName, "Jane")
        XCTAssertNil(user.lastName)
        XCTAssertNil(user.avatar)
        XCTAssertEqual(user.signature, "abc123")
    }

    func testVoteResponseDecoding() throws {
        let json = """
        {
            "success": true,
            "voted": false,
            "vote_count": 7
        }
        """
        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(VoteResponse.self, from: data)
        XCTAssertTrue(response.success)
        XCTAssertFalse(response.voted)
        XCTAssertEqual(response.voteCount, 7)
    }

    // MARK: - JotReview Error

    func testJotReviewErrorDescriptions() {
        let notConfigured = JotReviewError.notConfigured
        XCTAssertNotNil(notConfigured.errorDescription)
        XCTAssertTrue(notConfigured.errorDescription!.contains("not configured"))

        let httpError = JotReviewError.httpError(statusCode: 404, message: "Not found")
        XCTAssertTrue(httpError.errorDescription!.contains("404"))
        XCTAssertTrue(httpError.errorDescription!.contains("Not found"))

        let paramError = JotReviewError.invalidParameter("bad url")
        XCTAssertTrue(paramError.errorDescription!.contains("bad url"))
    }
}
