// swift-tools-version:5.2

/*
 This source file is part of the Swift.org open source project
 
 Copyright (c) 2019 - 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception
 
 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */


import PackageDescription

let package = Package(
    name: "swift-tools-support-core",
    products: [
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
    dependencies: [
        .package(url: "https://github.com/apple/swift-system.git", .upToNextMinor(from: "0.0.1"))
    ],
    targets: [
        
        // MARK: Tools support core targets
        
        .target(
            /** Shim target to import missing C headers in Darwin and Glibc modulemap. */
            name: "TSCclibc",
            dependencies: []),
        .target(
            /** Cross-platform access to bare `libc` functionality. */
            name: "TSCLibc",
            dependencies: []),
        .target(
            /** TSCBasic support library */
            name: "TSCBasic",
            dependencies: ["TSCLibc", "TSCclibc",
                           .product(name: "SystemPackage", package: "swift-system")]),
        .target(
            /** Abstractions for common operations, should migrate to TSCBasic */
            name: "TSCUtility",
            dependencies: ["TSCBasic", "TSCclibc"]),
        
        // MARK: Additional Test Dependencies
        
        .target(
            /** Generic test support library */
            name: "TSCTestSupport",
            dependencies: ["TSCBasic", "TSCUtility"]),
        
        
        // MARK: Tools support core tests
        
        .testTarget(
            name: "TSCBasicTests",
            dependencies: ["TSCTestSupport", "TSCclibc"]),
        .testTarget(
            name: "TSCBasicPerformanceTests",
            dependencies: ["TSCBasic", "TSCTestSupport"]),
        .testTarget(
            name: "TSCTestSupportTests",
            dependencies: ["TSCTestSupport"]),
        .testTarget(
            name: "TSCUtilityTests",
            dependencies: ["TSCUtility", "TSCTestSupport"]),
    ]
)
