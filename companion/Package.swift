// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RouterCompanion",
    platforms: [.macOS(.v14)],
    products: [.library(name: "CompanionCore", targets: ["CompanionCore"]),
               .executable(name: "CodexProjectRouter", targets: ["CodexProjectRouter"])],
    targets: [
        .target(name: "CompanionCore"),
        .executableTarget(name: "CodexProjectRouter", dependencies: ["CompanionCore"]),
        .testTarget(name: "CompanionAppTests", dependencies: ["CodexProjectRouter", "CompanionCore"]),
        .testTarget(name: "CompanionCoreTests", dependencies: ["CompanionCore"], resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v5]
)
