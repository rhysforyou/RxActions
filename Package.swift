// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "RxActions",
    products: [
        .library(
            name: "RxActions",
            targets: ["RxActions"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift.git", "4.3.0" ..< "5.0.0"),
        .package(url: "https://github.com/Quick/Quick.git", "1.3.0" ..< "2.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", "7.0.0" ..< "8.0.0"),
    ],
    targets: [
        .target(
            name: "RxActions",
            dependencies: ["RxSwift", "RxCocoa"]),
        .testTarget(
            name: "RxActionsTests",
            dependencies: [
                "RxActions",
                "RxSwift",
                "RxCocoa",
                "RxTest",
                "RxBlocking",
                "Quick",
                "Nimble",
            ]),
    ],
    swiftLanguageVersions: [.v4_2]
)
