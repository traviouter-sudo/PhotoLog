// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhotoLog",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PhotoLog", targets: ["PhotoLog"])
    ],
    targets: [
        .executableTarget(
            name: "PhotoLog",
            path: "PhotoLog"
        )
    ]
)
