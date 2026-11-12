// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "@capawesome/cordova-live-update",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "@capawesome/cordova-live-update", targets: ["CapawesomeCordovaLiveUpdate"])
    ],
    dependencies: [
        .package(url: "https://github.com/apache/cordova-ios.git", branch: "master"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "CapawesomeCordovaLiveUpdate",
            dependencies: [
                .product(name: "Cordova", package: "cordova-ios"),
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "src/ios"
        )
    ]
)
