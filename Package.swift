// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShiftProWorkspace",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ShiftProKit",
            targets: ["ShiftProKit"]
        )
    ],
    dependencies: [
        // TODO: Update versions after confirming with Xcode/SPM.
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.0.0"),
        .package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.0.0"),
        .package(url: "https://github.com/danielgindi/Charts.git", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "ShiftProKit",
            dependencies: [
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "Lottie", package: "lottie-ios"),
                .product(name: "Charts", package: "Charts")
            ]
        )
    ]
)
