// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FoundryWorldSwitcher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "FoundryWorldSwitcher",
            targets: ["FoundryWorldSwitcher"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/DiscordBM/DiscordBM", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://gitlab.com/mflint/HTML2Markdown", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
        	name: "FoundryWorldSwitcher",
        	dependencies: ["DiscordBM", "HTML2Markdown"]
        ),
    ]
)
