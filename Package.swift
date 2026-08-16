// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CourtVoice",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "CourtVoiceCore", targets: ["CourtVoiceCore"]),
        .library(name: "CourtVoiceAI", targets: ["CourtVoiceAI"])
    ],
    targets: [
        .target(name: "CourtVoiceCore"),
        .target(
            name: "CourtVoiceAI",
            dependencies: ["CourtVoiceCore"]
        ),
        .testTarget(
            name: "CourtVoiceCoreTests",
            dependencies: ["CourtVoiceCore"]
        ),
        .testTarget(
            name: "CourtVoiceAITests",
            dependencies: ["CourtVoiceAI", "CourtVoiceCore"]
        )
    ]
)
