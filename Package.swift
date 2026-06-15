// swift-tools-version: 6.0

import PackageDescription
import Foundation

let onnxRuntimeRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appending(path: "assets/runtime/onnxruntime-osx-arm64-1.26.0")
let onnxRuntimeIncludePath = onnxRuntimeRoot.appending(path: "include").path
let onnxRuntimeLibraryPath = onnxRuntimeRoot.appending(path: "lib").path
let onnxRuntimeLinkerSettings: [LinkerSetting] = [
    .linkedLibrary("sqlite3"),
    .unsafeFlags([
        "-L", onnxRuntimeLibraryPath,
        "-lonnxruntime",
        "-Xlinker", "-rpath",
        "-Xlinker", onnxRuntimeLibraryPath,
        "-Xlinker", "-rpath",
        "-Xlinker", "@executable_path/../Frameworks"
    ])
]

let package = Package(
    name: "HifzTracker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "HifzCore", targets: ["HifzCore"]),
        .executable(name: "HifzTracker", targets: ["HifzTracker"])
    ],
    targets: [
        .target(
            name: "COnnxRuntimeShim",
            cSettings: [
                .unsafeFlags(["-I", onnxRuntimeIncludePath])
            ]
        ),
        .target(
            name: "HifzCore",
            dependencies: ["COnnxRuntimeShim"],
            linkerSettings: onnxRuntimeLinkerSettings
        ),
        .testTarget(
            name: "HifzCoreTests",
            dependencies: ["HifzCore"]
        ),
        .executableTarget(
            name: "HifzTracker",
            dependencies: ["HifzCore"],
            path: "HifzTracker",
            exclude: ["Resources"]
        )
    ]
)
