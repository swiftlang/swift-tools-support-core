// swift-tools-version:5.7

/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2019 - 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */


import PackageDescription
import class Foundation.ProcessInfo

let macOSPlatform: SupportedPlatform
if let deploymentTarget = ProcessInfo.processInfo.environment["SWIFTTSC_MACOS_DEPLOYMENT_TARGET"] {
    macOSPlatform = .macOS(deploymentTarget)
} else {
    macOSPlatform = .macOS(.v10_15)
}

let CMakeFiles = ["CMakeLists.txt"]

let package = Package(
    name: "swift-tools-support-core",
    platforms: [
        macOSPlatform,
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "TSCBasic",
            targets: ["TSCBasic"]),
        .library(
            name: "SwiftToolsSupport",
            type: .dynamic,
            targets: ["TSCBasic", "TSCUtility"]),
        .library(
            name: "SwiftToolsSupport-auto",
            targets: ["TSCBasic", "TSCUtility"]),

        .library(
            name: "TSCTestSupport",
            targets: ["TSCTestSupport"]),
    ],
    dependencies: [],
    targets: [

        // MARK: Tools support core targets

        .target(
            /** Shim target to import missing C headers in Darwin and Glibc modulemap. */
            name: "TSCclibc",
            dependencies: [],
            exclude: CMakeFiles,
            cSettings: [
              .define("_GNU_SOURCE", .when(platforms: [.linux])),
            ]),
        .target(
            /** Cross-platform access to bare `libc` functionality. */
            name: "TSCLibc",
            dependencies: [],
            exclude: CMakeFiles),
        .target(
            /** TSCBasic support library */
            name: "TSCBasic",
            dependencies: [
              "TSCLibc",
              "TSCclibc",
              .product(name: "SystemPackage", package: "swift-system"),
            ],
            exclude: CMakeFiles + ["README.md"],
            cxxSettings: [
              .define("_CRT_SECURE_NO_WARNINGS", .when(platforms: [.windows])),
            ],
            linkerSettings: [
              .linkedLibrary("Pathcch", .when(platforms: [.windows])),
            ]),
        .target(
            /** Abstractions for common operations, should migrate to TSCBasic */
            name: "TSCUtility",
            dependencies: ["TSCBasic", "TSCclibc"],
            exclude: CMakeFiles),

        // MARK: Additional Test Dependencies

        .target(
            /** Generic test support library */
            name: "TSCTestSupport",
            dependencies: ["TSCBasic", "TSCUtility"]),


        // MARK: Tools support core tests

        .testTarget(
            name: "TSCBasicTests",
            dependencies: ["TSCTestSupport", "TSCclibc"],
            exclude: ["processInputs", "Inputs"]),
        .testTarget(
            name: "TSCBasicPerformanceTests",
            dependencies: ["TSCBasic", "TSCTestSupport"]),
        .testTarget(
            name: "TSCTestSupportTests",
            dependencies: ["TSCTestSupport"]),
        .testTarget(
            name: "TSCUtilityTests",
            dependencies: ["TSCUtility", "TSCTestSupport"],
            exclude: ["pkgconfigInputs", "Inputs"]),
    ]
)

 if ProcessInfo.processInfo.environment["SWIFTCI_USE_LOCAL_DEPS"] == nil {
     package.dependencies += [
         .package(url: "https://github.com/apple/swift-system.git", from: "1.1.1"),
     ]
 } else {
     package.dependencies += [
         .package(path: "../swift-system"),
     ]
 }
