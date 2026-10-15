// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CursorDrift",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CursorDrift", targets: ["CursorDrift"])],
    targets: [.executableTarget(name: "CursorDrift")]
)
