// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebSocketDist",
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", branch: "main"),
        .package(url: "https://github.com/otp-interop/swift-external-term-format", branch: "main"),
        .package(url: "https://github.com/swiftwasm/swift-dlmalloc", branch: "0.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "WebSocketDist",
            dependencies: [
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),

                .product(name: "ExternalTermFormat", package: "swift-external-term-format"),

                .product(name: "dlmalloc", package: "swift-dlmalloc"),
            ],
            cSettings: [
                .unsafeFlags([
                    "-fdeclspec"
                ])
            ],
            swiftSettings: [
                .enableExperimentalFeature("Embedded"),
                .enableExperimentalFeature("Extern"),
                .unsafeFlags([
                    "-Xfrontend", "-gnone",
                    "-Xfrontend", "-disable-stack-protector"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xclang-linker", "-nostdlib",
                    "-Xlinker", "--no-entry",
                    "-Xlinker", "--export-if-defined=__main_argc_argv"
                ])
            ]
        ),
        .testTarget(
            name: "WebSocketDistTests",
            dependencies: [
                .product(name: "JavaScriptEventLoopTestSupport", package: "JavaScriptKit"),
            ]
        )
    ]
)
