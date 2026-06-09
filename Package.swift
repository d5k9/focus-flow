// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FocusFlowKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "FocusFlowKit", targets: ["FocusFlowKit"]),
    ],
    targets: [
        .target(
            name: "FocusFlowKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "FocusFlowKitTests",
            dependencies: ["FocusFlowKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
