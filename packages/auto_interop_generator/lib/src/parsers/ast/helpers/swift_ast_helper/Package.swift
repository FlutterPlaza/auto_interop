// swift-tools-version: 5.9
import PackageDescription

#if compiler(>=6.0)
let syntaxVersion: Range<Version> = "600.0.0"..<"700.0.0"
#else
let syntaxVersion: Range<Version> = "510.0.0"..<"511.0.0"
#endif

let package = Package(
    name: "swift_ast_helper",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", syntaxVersion),
    ],
    targets: [
        .executableTarget(
            name: "swift_ast_helper",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            path: "Sources"
        ),
    ]
)
