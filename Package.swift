// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CopyShelf",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CopyShelf", targets: ["CopyShelf"])
    ],
    targets: [
        .executableTarget(
            name: "CopyShelf",
            linkerSettings: [.linkedFramework("Carbon")]
        )
    ]
)
