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

        let macos = try? Triple("x86_64-apple-macosx10.15")
        XCTAssertNotNil(macos!)
        XCTAssertEqual(macos!.osVersion, "10.15")
        let newVersion = "10.12"
        let tripleString = macos!.tripleString(forPlatformVersion: newVersion)
        XCTAssertEqual(tripleString, "x86_64-apple-macosx10.12")

        let android = try? Triple("aarch64-unknown-linux-android24")
        XCTAssertNotNil(android)
        XCTAssertEqual(android!.os, .linux)
        XCTAssertEqual(android!.abiVersion, "24")
    }
}
