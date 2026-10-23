// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "chubby-cat",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "chubby-cat", targets: ["ChubbyCat"])],
    targets: [
        .target(name: "ChubbyCatCore"),
        .executableTarget(name: "ChubbyCat", dependencies: ["ChubbyCatCore"], resources: [.copy("Resources")]),
        .executableTarget(name: "ChubbyCatChecks", dependencies: ["ChubbyCatCore"], path: "Tests/ChubbyCatCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
