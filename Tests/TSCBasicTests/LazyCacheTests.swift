/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest

import TSCBasic

class LazyCacheTests: XCTestCase {
    private class Foo {
        var numCalls = 0

        var bar: Int { return barCache.getValue(self) }
        var barCache = LazyCache<Foo, Int>(someExpensiveMethod)
        func someExpensiveMethod() -> Int {
            numCalls += 1
            return 42
        }

    }

    func testBasics() {
        for _ in 0..<10 {
            let foo = Foo()
            XCTAssertEqual(foo.numCalls, 0)
            for _ in 0..<10 {
                XCTAssertEqual(foo.bar, 42)
                XCTAssertEqual(foo.numCalls, 1)
            }
        }
    }

    func testThreadSafety() {
        let dispatchGroup = DispatchGroup()
        let exp = expectation(description: "multi thread")
        for _ in 0..<10 {
            let foo = Foo()
            for _ in 0..<10 {
                dispatchGroup.enter()
                DispatchQueue.global().async {
                    XCTAssertEqual(foo.bar, 42)
                    dispatchGroup.leave()

                    XCTAssertEqual(foo.numCalls, 1)
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            exp.fulfill()
        }

        wait(for: [exp], timeout: 0.2)
    }
}
