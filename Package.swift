// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "JotReview",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "JotReview", targets: ["JotReview"]),
    ],
    targets: [
        .target(name: "JotReview", path: "Sources/JotReview"),
        .testTarget(name: "JotReviewTests", dependencies: ["JotReview"], path: "Tests/JotReviewTests"),
    ]
)
