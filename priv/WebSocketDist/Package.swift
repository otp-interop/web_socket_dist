// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebSocketDist",
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", branch: "main"),
        .package(url: "https://github.com/swiftwasm/WebAPIKit.git", branch: "main"),
        .package(path: "/Users/carson.katri/Documents/LiveViewNative/ExternalTermFormat")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "WebSocketDist",
            dependencies: [
                .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
                .product(name: "WebSockets", package: "WebAPIKit"),

                .product(name: "ExternalTermFormat", package: "ExternalTermFormat"),
            ]),
        .testTarget(
            name: "WebSocketDistTests",
            dependencies: [
                .product(name: "JavaScriptEventLoopTestSupport", package: "JavaScriptKit"),
            ]
        )
    ]
)
