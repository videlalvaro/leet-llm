// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LeetLLM",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "LeetLLMCore", targets: ["LeetLLMCore"]),
        .library(name: "LeetLessonKit", targets: ["LeetLessonKit"]),
        .library(name: "LeetRunnerProtocol", targets: ["LeetRunnerProtocol"]),
        .library(name: "LeetLLMRuntime", targets: ["LeetLLMRuntime"]),
        .library(name: "LeetRunnerClient", targets: ["LeetRunnerClient"]),
        .library(name: "LeetWorkspaceKit", targets: ["LeetWorkspaceKit"]),
        .executable(name: "leetllm", targets: ["LeetLLMCLI"]),
        .executable(name: "leetllm-runner", targets: ["LeetLLMRunner"]),
        .executable(name: "leetllm-studio", targets: ["LeetLLMStudio"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/gonzalezreal/textual",
            exact: "0.5.0"
        ),
        .package(
            url: "https://github.com/jpsim/Yams",
            exact: "6.2.2"
        ),
    ],
    targets: [
        .target(name: "LeetLLMCore"),
        .target(name: "LeetRunnerProtocol"),
        .target(
            name: "LeetRunnerClient",
            dependencies: ["LeetRunnerProtocol"]
        ),
        .target(name: "LeetWorkspaceKit"),
        .target(
            name: "LeetLessonKit",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
            ]
        ),
        .target(
            name: "LeetLLMExercises",
            dependencies: ["LeetLLMCore"],
            resources: [.copy("Metal")]
        ),
        .target(
            name: "LeetLLMSolutions",
            dependencies: ["LeetLLMCore"],
            resources: [.copy("Metal")]
        ),
        .target(
            name: "LeetLLMRuntime",
            dependencies: [
                "LeetLLMCore",
                "LeetLLMExercises",
                "LeetLLMSolutions",
                "LeetRunnerProtocol",
            ],
            path: "Sources/LeetLLMCLI"
        ),
        .executableTarget(
            name: "LeetLLMCLI",
            dependencies: ["LeetLLMRuntime"],
            path: "Sources/LeetLLMCLIEntry"
        ),
        .executableTarget(
            name: "LeetLLMRunner",
            dependencies: ["LeetLLMRuntime", "LeetRunnerProtocol"],
            linkerSettings: [.linkedFramework("Security")]
        ),
        .executableTarget(
            name: "LeetLLMStudio",
            dependencies: [
                "LeetLessonKit",
                "LeetLLMRuntime",
                "LeetRunnerClient",
                "LeetRunnerProtocol",
                "LeetWorkspaceKit",
                .product(name: "Textual", package: "textual"),
            ],
            resources: [.copy("Resources")],
            linkerSettings: [.linkedFramework("Security")]
        ),
        .testTarget(
            name: "LeetLessonKitTests",
            dependencies: [
                "LeetLessonKit",
                .product(name: "Textual", package: "textual"),
            ]
        ),
        .testTarget(
            name: "LeetLLMRuntimeTests",
            dependencies: [
                "LeetLessonKit",
                "LeetLLMCore",
                "LeetLLMRuntime",
                "LeetRunnerProtocol",
            ]
        ),
        .testTarget(
            name: "LeetWorkspaceKitTests",
            dependencies: ["LeetWorkspaceKit"]
        ),
        .testTarget(
            name: "LeetRunnerClientTests",
            dependencies: [
                "LeetRunnerClient",
                "LeetRunnerProtocol",
                "LeetWorkspaceKit",
            ]
        ),
        .testTarget(
            name: "LeetLLMCoreTests",
            dependencies: ["LeetLLMCore", "LeetLLMSolutions"]
        ),
        .testTarget(
            name: "LeetLLMStudioTests",
            dependencies: ["LeetLLMStudio", "LeetLessonKit"]
        ),
    ]
)