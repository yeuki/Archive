// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ArchiveCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "ArchiveCore", targets: ["ArchiveCore"])],
    targets: [
        .target(name: "ArchiveCore"),
        .testTarget(name: "ArchiveCoreTests", dependencies: ["ArchiveCore"])
    ]
)
