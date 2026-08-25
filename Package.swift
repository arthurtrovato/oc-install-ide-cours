// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeteoblueWeather",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "MeteoblueCore", targets: ["MeteoblueCore"])
    ],
    targets: [
        .target(
            name: "MeteoblueCore",
            path: "Sources/MeteoblueCore"
        ),
        .testTarget(
            name: "MeteoblueCoreTests",
            dependencies: ["MeteoblueCore"],
            path: "Tests/MeteoblueCoreTests",
            resources: [.copy("Fixtures")]
        )
    ],
    swiftLanguageModes: [.v5]
)
