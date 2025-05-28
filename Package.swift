// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GodotSwiftMcp",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "GodotSwiftMcp",
            targets: ["GodotSwiftMcp"]),
        .library(
            name: "GodotSwiftMcpSocket",
            targets: ["GodotSwiftMcpSocket"]),

        .executable(
            name: "godot-mcp-server-cli",
            targets: ["GodotMcpServerCli"])
    ],
    dependencies: [
            .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.8.2"),
            .package(url: "https://github.com/loopwork-ai/JSONSchema.git", from: "1.1.0"),
            .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.6")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "GodotSwiftMcp", 
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "JSONSchema", package: "JSONSchema")
            ]
        ),
        .target(
            name: "GodotSwiftMcpSocket",
            dependencies: [
                .target(name: "GodotSwiftMcp"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "JSONSchema", package: "JSONSchema"),
                .product(name: "Starscream", package: "Starscream")
            ]
        ),
        .executableTarget(
            name: "GodotMcpServerCli",
            dependencies: [
                "GodotSwiftMcp",
                "GodotSwiftMcpSocket",
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "JSONSchema", package: "JSONSchema"),
                .product(name: "Starscream", package: "Starscream")
            ]
        ),
        .testTarget(
            name: "GodotSwiftMcpTests",
            dependencies: ["GodotSwiftMcp"]
        ),
    ]
)
