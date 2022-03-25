/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import TSCBasic
import XCTest

import TSCBasic

class EditDistanceTests: XCTestCase {

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testEditDistanceWithCollectionDiff() {
        XCTAssertEqual(collectionDiffEditDistance("Foo", "Fo"), 1)
        XCTAssertEqual(collectionDiffEditDistance("Foo", "Foo"), 0)
        XCTAssertEqual(collectionDiffEditDistance("Bar", "Foo"), 3)
        XCTAssertEqual(collectionDiffEditDistance("ABCDE", "ABDE"), 1)
        XCTAssertEqual(collectionDiffEditDistance("sunday", "saturday"), 3)
        XCTAssertEqual(collectionDiffEditDistance("FOO", "foo"), 3)
    }

    func testInternalEditDistance() {
        XCTAssertEqual(internalEditDistance("Foo", "Fo"), 1)
        XCTAssertEqual(internalEditDistance("Foo", "Foo"), 0)
        XCTAssertEqual(internalEditDistance("Bar", "Foo"), 3)
        XCTAssertEqual(internalEditDistance("ABCDE", "ABDE"), 1)
        XCTAssertEqual(internalEditDistance("sunday", "saturday"), 3)
        XCTAssertEqual(internalEditDistance("FOO", "foo"), 3)
    }
}
