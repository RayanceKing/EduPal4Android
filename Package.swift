// swift-tools-version: 6.0
// This is a Skip (https://skip.tools) package.
import PackageDescription

let package = Package(
    name: "edupal4android",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "EduPal", type: .dynamic, targets: ["EduPal"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.6.32"),
        .package(url: "https://source.skip.tools/skip-fuse-ui.git", from: "1.0.0"), 
        .package(url: "https://github.com/RayanceKing/CCZUKit", branch: "main"), 
        .package(url: "https://github.com/gonzalezreal/MarkdownUI.git", from: "2.4.1"),
        .package(url: "https://github.com/supabase-community/supabase-swift", from: "2.3.0"), 
        .package(url: "https://github.com/onevcat/Kingfisher", from: "8.6.0")
    ],
    targets: [
        .target(name: "EduPal", dependencies: [
            .product(name: "SkipFuseUI", package: "skip-fuse-ui"),
            .product(name: "CCZUKit", package: "CCZUKit"), 
            .product(name: "MarkdownUI", package: "MarkdownUI"),
            .product(name: "Supabase", package: "supabase-swift"), 
            .product(name: "Kingfisher", package: "Kingfisher")
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)
