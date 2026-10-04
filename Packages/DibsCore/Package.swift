// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DibsCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DibsCore", targets: ["DibsCore"]),
        .library(name: "DibsOCR", targets: ["DibsOCR"]),
        .library(name: "DibsLLM", targets: ["DibsLLM"]),
    ],
    targets: [
        .target(name: "DibsCore"),
        .target(name: "DibsOCR", dependencies: ["DibsCore"]),
        .target(name: "DibsLLM", dependencies: ["DibsCore"]),
        .target(name: "DibsEval", dependencies: ["DibsCore"]),
        .executableTarget(name: "dibs-eval", dependencies: ["DibsCore", "DibsOCR", "DibsLLM", "DibsEval"]),
        .testTarget(
            name: "DibsCoreTests",
            dependencies: ["DibsCore", "DibsEval"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
