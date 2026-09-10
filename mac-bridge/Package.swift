// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iosClawMacBridge",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "iosclaw-mac-bridge", targets: ["iosClawMacBridge"])
    ],
    targets: [
        .executableTarget(name: "iosClawMacBridge")
    ]
)
