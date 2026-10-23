// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeskKitty",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "DeskKitty", targets: ["DeskKitty"])],
    targets: [
        .target(name: "DeskKittyCore"),
        .executableTarget(name: "DeskKitty", dependencies: ["DeskKittyCore"], resources: [.copy("Resources")]),
        .executableTarget(name: "DeskKittyChecks", dependencies: ["DeskKittyCore"], path: "Tests/DeskKittyCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
