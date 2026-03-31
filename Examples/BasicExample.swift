// BasicExample.swift
// A complete SwiftUI example app demonstrating the JotReview iOS SDK.
//
// This file is a standalone reference — copy it into a new Xcode project
// that has the JotReview package added via SPM to run it.

import SwiftUI
import JotReview

// MARK: - App Entry Point

@main
struct BasicExampleApp: App {
    init() {
        // Initialize JotReview as early as possible.
        // Replace with your actual project ID from Settings > Login & SSO.
        JotReview.setup(projectId: "proj_abc123")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: - Root View

/// The root view manages authentication state and switches between
/// a logged-out welcome screen and the main content.
struct RootView: View {
    @State private var isLoggedIn = false
    @State private var userName = ""

    var body: some View {
        if isLoggedIn {
            MainContentView(
                userName: userName,
                onLogout: {
                    JotReview.logout()
                    isLoggedIn = false
                    userName = ""
                }
            )
        } else {
            LoginView(
                onLogin: { name in
                    // After your real auth flow completes, identify the user.
                    // In production you would pass a server-generated HMAC signature
                    // for secure identity verification.
                    JotReview.identify(
                        userId: "user_42",
                        email: "\(name.lowercased())@example.com",
                        firstName: name
                    )
                    userName = name
                    isLoggedIn = true
                }
            )
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    let onLogin: (String) -> Void
    @State private var name = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("JotReview Example")
                .font(.title.bold())

            Text("Sign in to try the feedback SDK")
                .foregroundStyle(.secondary)

            TextField("Your name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)
                .submitLabel(.go)
                .onSubmit { loginIfValid() }

            Button("Sign In") { loginIfValid() }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()
        }
        .padding()
    }

    private func loginIfValid() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onLogin(trimmed)
    }
}

// MARK: - Main Content View

/// After login this view shows three actions: Feedback, Roadmap, and Changelog.
/// Each opens its respective JotReview sheet via SwiftUI view modifiers.
struct MainContentView: View {
    let userName: String
    let onLogout: () -> Void

    @State private var showFeedback = false
    @State private var showRoadmap = false
    @State private var showChangelog = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Welcome, \(userName)", systemImage: "person.circle.fill")
                        .font(.headline)
                }

                Section("JotReview") {
                    Button {
                        showFeedback = true
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                    }

                    Button {
                        showRoadmap = true
                    } label: {
                        Label("View Roadmap", systemImage: "map")
                    }

                    Button {
                        showChangelog = true
                    } label: {
                        Label("What's New", systemImage: "sparkles")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        onLogout()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Example App")
            // Attach JotReview sheet modifiers to the list.
            // Only one sheet presents at a time — SwiftUI manages dismissal.
            .jotReviewFeedback(isPresented: $showFeedback)
            .jotReviewRoadmap(isPresented: $showRoadmap)
            .jotReviewChangelog(isPresented: $showChangelog)
        }
    }
}
