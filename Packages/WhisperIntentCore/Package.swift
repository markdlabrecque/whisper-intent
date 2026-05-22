// swift-tools-version: 6.0
import PackageDescription

/// WhisperKit is pinned to an exact version. Bumping it triggers a re-run of
/// spike S1 (progress callbacks) — see docs/spikes/S1-progress-callbacks.md.
let whisperKitVersion: Version = "0.18.0"

let package = Package(
  name: "WhisperIntentCore",
  platforms: [
    // iOS 26 is the real deployment target for the app.
    // macOS is declared only so `swift build` / `swift test` work on developer
    // machines and CI runners; the macOS minimum tracks WhisperKit's requirement.
    .iOS("26.0"),
    .macOS("13.0")
  ],
  products: [
    .library(
      name: "WhisperIntentCore",
      targets: ["WhisperIntentCore"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", exact: whisperKitVersion)
  ],
  targets: [
    .target(
      name: "WhisperIntentCore",
      dependencies: [
        .product(name: "WhisperKit", package: "WhisperKit")
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ]
    ),
    .testTarget(
      name: "WhisperIntentCoreTests",
      dependencies: ["WhisperIntentCore"],
      swiftSettings: [
        .swiftLanguageMode(.v6)
      ]
    )
  ]
)
