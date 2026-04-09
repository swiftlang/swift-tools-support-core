/*
 This source file is part of the Swift.org open source project

 Copyright 2016 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import TSCBasic

class StringConversionTests: XCTestCase {

    func testShellEscaped() {

        var str = "hello-_123"
        XCTAssertEqual("hello-_123", str.spm_shellEscaped())

        str = "hello world"
        XCTAssertEqual("'hello world'", str.spm_shellEscaped())

        str = "hello 'world"
        str.spm_shellEscape()
        XCTAssertEqual("'hello '\\''world'", str)

        str = "hello world swift"
        XCTAssertEqual("'hello world swift'", str.spm_shellEscaped())

        str = "hello?world"
        XCTAssertEqual("'hello?world'", str.spm_shellEscaped())

        str = "hello\nworld"
        XCTAssertEqual("'hello\nworld'", str.spm_shellEscaped())

        str = "hello\nA\"B C>D*[$;()^><"
        XCTAssertEqual("'hello\nA\"B C>D*[$;()^><'", str.spm_shellEscaped())

        #if os(Windows)
        // Trailing backslash must be doubled so the closing quote is not escaped.
        str = "hello world\\"
        XCTAssertEqual("\"hello world\\\\\"", str.spm_shellEscaped())

        // Embedded double-quote is escaped with a backslash.
        str = "hello\"world"
        XCTAssertEqual("\"hello\\\"world\"", str.spm_shellEscaped())

        // Backslash immediately before an embedded double-quote: the backslash is doubled,
        // then the quote is escaped with another backslash.
        str = "hello\\\"world"
        XCTAssertEqual("\"hello\\\\\\\"world\"", str.spm_shellEscaped())
        #endif
    }

    func testLocalizedJoin() {
        XCTAssertEqual("foo", ["foo"].spm_localizedJoin(type: .conjunction))
        XCTAssertEqual("foo", ["foo"].spm_localizedJoin(type: .disjunction))

        XCTAssertEqual("foo or bar", ["foo", "bar"].spm_localizedJoin(type: .disjunction))
        XCTAssertEqual("foo, bar, and baz", ["foo", "bar", "baz"].spm_localizedJoin(type: .conjunction))
    }
}
