// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "HuntCore", platforms: [.iOS(.v17), .macOS(.v14)], products: [.library(name: "HuntCore", targets: ["HuntCore"])], targets: [.target(name: "HuntCore"), .testTarget(name: "HuntCoreTests", dependencies: ["HuntCore"])])
