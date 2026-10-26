// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Awake",
    platforms: [.macOS(.v14)],
    targets: [
        // The menu bar app (SwiftUI MenuBarExtra). Bundled into an .app by build.sh.
        .executableTarget(
            name: "Awake",
            linkerSettings: [
                // IOKit is normally auto-linked by `import IOKit.pwr_mgt`; naming it explicitly
                // keeps the IOPMAssertion symbols resolvable under bare Command Line Tools too.
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        // The pure decisions (what an awake:// link asks, when to hold the Mac awake). Needs a full Xcode toolchain.
        .testTarget(name: "AwakeTests", dependencies: ["Awake"]),
    ]
)
