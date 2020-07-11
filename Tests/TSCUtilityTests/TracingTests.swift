// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import XCTest

import TSCUtility

class TracingTests: XCTestCase {
    func testBasics() {
        let event1 = Tracing.Event(cat: "cat", name: "name", id: "1", ph: .asyncBegin)
        var collection = Tracing.Collection()
        collection.events.append(event1)
        let event2 = Tracing.Event(cat: "cat", name: "name", id: "1", ph: .asyncEnd)
        collection.events.append(event2)
        XCTAssertEqual(collection.events.count, 2)
        var ctx = Context()
        ctx.set(collection)
        XCTAssertEqual(ctx.get(Tracing.Collection.self).events.count, 2)
    }
}
