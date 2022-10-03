/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import TSCUtility
import XCTest

class TripleTests : XCTestCase {
    func testTriple() {
        let linux = try? Triple("x86_64-unknown-linux-gnu")
        XCTAssertNotNil(linux)
        XCTAssertEqual(linux!.os, .linux)
        XCTAssertNil(linux!.osVersion)
        XCTAssertEqual(linux!.abi, .other(name: "gnu"))
        XCTAssertNil(linux!.abiVersion)

        let macos = try? Triple("x86_64-apple-macosx10.15")
        XCTAssertNotNil(macos!)
        XCTAssertEqual(macos!.osVersion, "10.15")
        let newVersion = "10.12"
        let tripleString = macos!.tripleString(forPlatformVersion: newVersion)
        XCTAssertEqual(tripleString, "x86_64-apple-macosx10.12")
        let macosNoX = try? Triple("x86_64-apple-macos12.2")
        XCTAssertNotNil(macosNoX!)
        XCTAssertEqual(macosNoX!.os, .macOS)
        XCTAssertEqual(macosNoX!.osVersion, "12.2")

        let android = try? Triple("aarch64-unknown-linux-android24")
        XCTAssertNotNil(android)
        XCTAssertEqual(android!.os, .linux)
        XCTAssertEqual(android!.abi, .android)
        XCTAssertEqual(android!.abiVersion, "24")

        let linuxWithABIVersion = try? Triple("x86_64-unknown-linux-gnu42")
        XCTAssertEqual(linuxWithABIVersion!.abi, .other(name: "gnu"))
        XCTAssertEqual(linuxWithABIVersion!.abiVersion, "42")
    }

    func testEquality() throws {
        let macOSTriple = try Triple("arm64-apple-macos")
        let macOSXTriple = try Triple("arm64-apple-macosx")
        XCTAssertEqual(macOSTriple, macOSXTriple)

        let intelMacOSTriple = try Triple("x86_64-apple-macos")
        XCTAssertNotEqual(macOSTriple, intelMacOSTriple)

        let linuxWithoutGNUABI = try Triple("x86_64-unknown-linux")
        let linuxWithGNUABI = try Triple("x86_64-unknown-linux-gnu")
        XCTAssertNotEqual(linuxWithoutGNUABI, linuxWithGNUABI)
    }

    func testWASI() throws {
        let wasi = try Triple("wasm32-unknown-wasi")

        // WASI dynamic libraries are only experimental,
        // but SwiftPM requires this property not to crash.
        _ = wasi.dynamicLibraryExtension
    }
}
