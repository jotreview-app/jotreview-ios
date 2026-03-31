# JotReview iOS SDK

The official Swift SDK for [JotReview](https://jotreview.app) -- collect feedback, display your roadmap, and share changelog updates natively in your iOS and macOS apps.

The SDK provides a lightweight Swift interface over JotReview's widget API with first-class SwiftUI support and UIKit compatibility. No external dependencies, no web views.

## Requirements

| Requirement | Minimum |
|-------------|---------|
| iOS | 15.0+ |
| macOS | 12.0+ |
| Swift | 5.7+ |
| Xcode | 14.0+ |

## Installation

### Swift Package Manager (Xcode)

1. In Xcode, go to **File > Add Package Dependencies...**
2. Enter the repository URL:
   ```
   https://github.com/jotreview/jotreview-ios
   ```
3. Select **Up to Next Major Version** with `1.0.0`.
4. Click **Add Package** and add the `JotReview` library to your target.

### Swift Package Manager (Package.swift)

Add JotReview as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jotreview/jotreview-ios", from: "1.0.0"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["JotReview"]
    ),
]
```

## Quick Start

Initialize the SDK as early as possible in your app lifecycle -- typically in your `App` struct's initializer or in `application(_:didFinishLaunchingWithOptions:)`.

```swift
import JotReview

@main
struct MyApp: App {
    init() {
        JotReview.setup(projectId: "YOUR_PROJECT_ID")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

You can find your **Project ID** in the JotReview dashboard under **Settings > Login & SSO**.

## User Identification

Identifying users ties feedback and votes to a known account. Call `identify` after your user logs in.

### Basic identification

```swift
JotReview.identify(userId: "user_123")
```

### With email

```swift
JotReview.identify(userId: "user_123", email: "john@example.com")
```

### Full profile

```swift
JotReview.identify(
    userId: "user_123",
    email: "john@example.com",
    firstName: "John",
    lastName: "Doe",
    avatar: "https://example.com/avatars/john.png"
)
```

### Secure mode (with signature)

When you enable secure identity verification in your JotReview settings, pass an HMAC-SHA256 signature generated on your server. This prevents users from impersonating others.

```swift
JotReview.identify(
    userId: "user_123",
    email: "john@example.com",
    firstName: "John",
    lastName: "Doe",
    avatar: "https://example.com/avatars/john.png",
    signature: "a1b2c3d4..." // HMAC-SHA256 of userId with your project secret
)
```

See [Server-Side Authentication](#server-side-authentication) for how to generate signatures on your backend.

### Logout

Clear the identified user when they log out. Anonymous visitor tracking resumes automatically.

```swift
JotReview.logout()
```

## SwiftUI Integration

The SDK provides SwiftUI view modifiers that present JotReview content as native sheets.

### Feedback

```swift
struct ContentView: View {
    @State private var showFeedback = false

    var body: some View {
        Button("Send Feedback") {
            showFeedback = true
        }
        .jotReviewFeedback(isPresented: $showFeedback)
    }
}
```

### Roadmap

```swift
struct ContentView: View {
    @State private var showRoadmap = false

    var body: some View {
        Button("View Roadmap") {
            showRoadmap = true
        }
        .jotReviewRoadmap(isPresented: $showRoadmap)
    }
}
```

### Changelog

```swift
struct ContentView: View {
    @State private var showChangelog = false

    var body: some View {
        Button("What's New") {
            showChangelog = true
        }
        .jotReviewChangelog(isPresented: $showChangelog)
    }
}
```

### Targeting a specific board

If your workspace has multiple boards, you can direct feedback to a specific one by passing its slug:

```swift
.jotReviewFeedback(isPresented: $showFeedback, board: "feature-requests")
```

### Complete SwiftUI example

```swift
import SwiftUI
import JotReview

@main
struct MyApp: App {
    init() {
        JotReview.setup(projectId: "YOUR_PROJECT_ID")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var showFeedback = false
    @State private var showRoadmap = false
    @State private var showChangelog = false

    var body: some View {
        NavigationStack {
            List {
                Button("Send Feedback") { showFeedback = true }
                Button("Roadmap") { showRoadmap = true }
                Button("What's New") { showChangelog = true }
            }
            .navigationTitle("My App")
            .jotReviewFeedback(isPresented: $showFeedback)
            .jotReviewRoadmap(isPresented: $showRoadmap)
            .jotReviewChangelog(isPresented: $showChangelog)
        }
    }
}
```

## UIKit Integration

For UIKit-based apps, the SDK provides imperative presentation methods that find the topmost view controller automatically.

### Present feedback

```swift
import JotReview

class SettingsViewController: UIViewController {
    @IBAction func feedbackTapped(_ sender: Any) {
        JotReview.showFeedback()
    }
}
```

### Target a specific board

```swift
JotReview.showFeedback(board: "bugs")
```

### Manual view controller presentation

For full control over the presentation style, instantiate `JotReviewViewController` directly:

```swift
let vc = JotReviewViewController(page: .feedback)
vc.modalPresentationStyle = .pageSheet
present(vc, animated: true)
```

Available pages: `.feedback`, `.roadmap`, `.changelog`.

## Server-Side Authentication

Secure identity verification uses HMAC-SHA256 to prevent client-side impersonation. Your server computes a signature from the user's ID and your **Project Secret** (found in **Settings > Login & SSO**), then passes it to the client.

**Never expose your project secret in client-side code.**

### Node.js

```javascript
const crypto = require("crypto");

function generateJotReviewSignature(userId, projectSecret) {
  return crypto
    .createHmac("sha256", projectSecret)
    .update(userId)
    .digest("hex");
}

// Usage
const signature = generateJotReviewSignature("user_123", process.env.JOTREVIEW_SECRET);
```

### Python

```python
import hmac
import hashlib

def generate_jotreview_signature(user_id: str, project_secret: str) -> str:
    return hmac.new(
        project_secret.encode("utf-8"),
        user_id.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()

# Usage
signature = generate_jotreview_signature("user_123", os.environ["JOTREVIEW_SECRET"])
```

### Ruby

```ruby
require "openssl"

def generate_jotreview_signature(user_id, project_secret)
  OpenSSL::HMAC.hexdigest("SHA256", project_secret, user_id)
end

# Usage
signature = generate_jotreview_signature("user_123", ENV["JOTREVIEW_SECRET"])
```

### PHP

```php
function generateJotReviewSignature(string $userId, string $projectSecret): string {
    return hash_hmac("sha256", $userId, $projectSecret);
}

// Usage
$signature = generateJotReviewSignature("user_123", getenv("JOTREVIEW_SECRET"));
```

### Passing the signature to the SDK

Once your server returns the signature to your iOS app (e.g. as part of the login response), pass it to `identify`:

```swift
JotReview.identify(
    userId: "user_123",
    email: "john@example.com",
    signature: signatureFromServer
)
```

## API Reference

### Setup

| Method | Description |
|--------|-------------|
| `JotReview.setup(projectId: String)` | Initialize the SDK with your project ID. Call once at app launch. |

### User Identity

| Method | Description |
|--------|-------------|
| `JotReview.identify(userId:email:firstName:lastName:avatar:signature:)` | Identify the current user. All parameters except `userId` are optional. |
| `JotReview.logout()` | Clear the identified user and revert to anonymous visitor tracking. |

### Presentation (Imperative)

| Method | Description |
|--------|-------------|
| `JotReview.showFeedback(board: String?)` | Present the feedback sheet. Optionally target a specific board by slug. |

### SwiftUI View Modifiers

| Modifier | Description |
|----------|-------------|
| `.jotReviewFeedback(isPresented: Binding<Bool>, board: String?)` | Present the feedback submission sheet. |
| `.jotReviewRoadmap(isPresented: Binding<Bool>)` | Present the public roadmap view. |
| `.jotReviewChangelog(isPresented: Binding<Bool>)` | Present the changelog / "What's New" view. |

### UIKit

| Class | Description |
|-------|-------------|
| `JotReviewViewController(page: JotReviewPage)` | A view controller you can present manually. Pages: `.feedback`, `.roadmap`, `.changelog`. |

### Models

| Type | Description |
|------|-------------|
| `UserIdentity` | Represents an identified user (id, email, firstName, lastName, avatar, signature). |
| `FeedbackRequest` | A feedback item with title, description, status, and vote count. |
| `ChangelogEntry` | A published changelog entry with title, body, and published date. |
| `WorkspaceInfo` | Workspace branding configuration (name, logo, colors, theme). |

## License

MIT
