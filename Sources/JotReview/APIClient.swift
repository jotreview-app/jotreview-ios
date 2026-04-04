import Foundation

// MARK: - Error Types

/// Errors that can occur when communicating with the JotReview API.
public enum JotReviewError: Error, LocalizedError {
    /// The SDK has not been configured. Call `JotReview.setup()` first.
    case notConfigured

    /// A required parameter was missing or invalid.
    case invalidParameter(String)

    /// The server returned a non-success HTTP status code.
    case httpError(statusCode: Int, message: String)

    /// The response body could not be decoded.
    case decodingError(Error)

    /// A network-level failure occurred.
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "JotReview SDK is not configured. Call JotReview.setup(projectId:) first."
        case .invalidParameter(let detail):
            return "Invalid parameter: \(detail)"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .decodingError(let underlying):
            return "Failed to decode response: \(underlying.localizedDescription)"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - API Client

/// URLSession-based HTTP client for the JotReview widget API (`/api/widget/v1/`).
///
/// All methods use modern Swift concurrency (async/await). The client is a
/// singleton — endpoint base URLs and project IDs are passed per-call so the
/// client itself is stateless.
internal final class APIClient: Sendable {

    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Public Endpoints

    /// Response from the init endpoint containing workspace info and feature flags.
    struct InitResult {
        let workspace: WorkspaceInfo
        let imageAttachmentsEnabled: Bool
    }

    /// Fetches workspace display configuration and feature flags.
    ///
    /// **GET** `/api/widget/v1/init?projectId=<id>`
    ///
    /// - Returns: An `InitResult` containing workspace info and feature flags.
    func fetchInit(projectId: String, baseURL: String) async throws -> InitResult {
        let url = try buildURL(base: baseURL, path: "/api/widget/v1/init", queryItems: [
            URLQueryItem(name: "projectId", value: projectId),
        ])

        let data = try await performGET(url: url)

        struct Features: Decodable {
            let image_attachments: Bool?
        }

        struct Envelope: Decodable {
            let workspace: WorkspaceInfo
            let features: Features?
        }

        do {
            let envelope = try decoder.decode(Envelope.self, from: data)
            return InitResult(
                workspace: envelope.workspace,
                imageAttachmentsEnabled: envelope.features?.image_attachments ?? false
            )
        } catch {
            throw JotReviewError.decodingError(error)
        }
    }

    /// Fetches top feedback requests ordered by vote count.
    ///
    /// **GET** `/api/widget/v1/requests?projectId=<id>&limit=<n>`
    ///
    /// - Returns: An array of `FeedbackRequest` values.
    func fetchRequests(projectId: String, baseURL: String, limit: Int = 50) async throws -> [FeedbackRequest] {
        let url = try buildURL(base: baseURL, path: "/api/widget/v1/requests", queryItems: [
            URLQueryItem(name: "projectId", value: projectId),
            URLQueryItem(name: "limit", value: String(limit)),
        ])

        let data = try await performGET(url: url)

        struct Envelope: Decodable {
            let requests: [FeedbackRequest]
        }

        do {
            let envelope = try decoder.decode(Envelope.self, from: data)
            return envelope.requests
        } catch {
            throw JotReviewError.decodingError(error)
        }
    }

    /// Fetches published changelog entries, newest first.
    ///
    /// **GET** `/api/widget/v1/changelog?projectId=<id>&limit=<n>`
    ///
    /// - Returns: An array of `ChangelogEntry` values.
    func fetchChangelog(projectId: String, baseURL: String, limit: Int = 20) async throws -> [ChangelogEntry] {
        let url = try buildURL(base: baseURL, path: "/api/widget/v1/changelog", queryItems: [
            URLQueryItem(name: "projectId", value: projectId),
            URLQueryItem(name: "limit", value: String(limit)),
        ])

        let data = try await performGET(url: url)

        struct Envelope: Decodable {
            let entries: [ChangelogEntry]
        }

        do {
            let envelope = try decoder.decode(Envelope.self, from: data)
            return envelope.entries
        } catch {
            throw JotReviewError.decodingError(error)
        }
    }

    /// Submits a new feedback request.
    ///
    /// **POST** `/api/widget/v1/submit`
    ///
    /// - Returns: The UUID string of the newly created request.
    func submitFeedback(projectId: String, baseURL: String, data submitData: SubmitData) async throws -> String {
        let url = try buildURL(base: baseURL, path: "/api/widget/v1/submit")

        let body: Data
        do {
            body = try encoder.encode(submitData)
        } catch {
            throw JotReviewError.decodingError(error)
        }

        let responseData = try await performPOST(url: url, body: body)

        do {
            let response = try decoder.decode(SubmitResponse.self, from: responseData)
            return response.requestId
        } catch {
            throw JotReviewError.decodingError(error)
        }
    }

    /// Toggles a vote on a feedback request for an anonymous visitor.
    ///
    /// **POST** `/api/widget/v1/vote`
    ///
    /// - Returns: A `VoteResponse` containing the new voted state and vote count.
    func toggleVote(projectId: String, baseURL: String, requestId: String, visitorId: String) async throws -> VoteResponse {
        let url = try buildURL(base: baseURL, path: "/api/widget/v1/vote")

        struct VoteBody: Encodable {
            let projectId: String
            let requestId: String
            let visitorId: String
        }

        let body: Data
        do {
            body = try encoder.encode(VoteBody(projectId: projectId, requestId: requestId, visitorId: visitorId))
        } catch {
            throw JotReviewError.decodingError(error)
        }

        let responseData = try await performPOST(url: url, body: body)

        do {
            let response = try decoder.decode(VoteResponse.self, from: responseData)
            return response
        } catch {
            throw JotReviewError.decodingError(error)
        }
    }

    /// Uploads an image to the server and returns the public URL.
    ///
    /// **POST** `/api/widget/v1/upload` (multipart/form-data)
    ///
    /// - Parameters:
    ///   - projectId: The workspace project ID.
    ///   - baseURL: The server base URL.
    ///   - imageData: The image file data (JPEG, PNG, GIF, or WebP).
    ///   - filename: The filename for the upload.
    ///   - mimeType: The MIME type (e.g. "image/jpeg").
    /// - Returns: The public URL of the uploaded image.
    func uploadImage(projectId: String, baseURL: String, imageData: Data, filename: String, mimeType: String) async throws -> String {
        let url = try buildURL(base: baseURL, path: "/api/widget/v1/upload")

        let boundary = UUID().uuidString
        var body = Data()

        // projectId field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"projectId\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(projectId)\r\n".data(using: .utf8)!)

        // file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let responseData = try await execute(request)

        struct UploadResponse: Decodable {
            let url: String
        }

        do {
            let response = try decoder.decode(UploadResponse.self, from: responseData)
            return response.url
        } catch {
            throw JotReviewError.decodingError(error)
        }
    }

    // MARK: - Private Helpers

    /// Constructs a URL from a base string, path, and optional query items.
    private func buildURL(base: String, path: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        guard var components = URLComponents(string: base) else {
            throw JotReviewError.invalidParameter("Invalid base URL: \(base)")
        }
        components.path = path
        components.queryItems = queryItems
        guard let url = components.url else {
            throw JotReviewError.invalidParameter("Could not construct URL from \(base)\(path)")
        }
        return url
    }

    /// Performs a GET request and returns the raw response data.
    private func performGET(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await execute(request)
    }

    /// Performs a POST request with a JSON body and returns the raw response data.
    private func performPOST(url: URL, body: Data) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        return try await execute(request)
    }

    /// Executes a URLRequest, validates the HTTP response, and extracts error messages.
    private func execute(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw JotReviewError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JotReviewError.networkError(
                NSError(domain: "JotReview", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Response was not an HTTP response.",
                ])
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Attempt to extract the error message from the JSON body
            var message = "Unknown error"
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorBody["error"] as? String {
                message = errorMessage
            }
            throw JotReviewError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        return data
    }
}
