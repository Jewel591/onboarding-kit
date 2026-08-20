// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OnboardingKit",
    platforms: [.iOS(.v17), .macOS(.v14), .visionOS(.v1)],
    products: [.library(name: "OnboardingKit", targets: ["OnboardingKit"])],
    targets: [
        .target(name: "OnboardingKit"),
        .testTarget(name: "OnboardingKitTests", dependencies: ["OnboardingKit"]),
    ],
    swiftLanguageModes: [.v6]
)
