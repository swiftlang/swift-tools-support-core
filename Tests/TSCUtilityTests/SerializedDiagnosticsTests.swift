/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
import TSCBasic
import TSCUtility

final class SerializedDiagnosticsTests: XCTestCase {
  func testReadSwiftDiagnosticWithNote() throws {
    let serializedDiagnosticsPath = AbsolutePath(#file).parentDirectory
      .appending(components: "Inputs", "multiblock.dia")
    let contents = try localFileSystem.readFileContents(serializedDiagnosticsPath)
    let serializedDiags = try SerializedDiagnostics(bytes: contents)

    XCTAssertEqual(serializedDiags.versionNumber, 2)
    XCTAssertEqual(serializedDiags.diagnostics.count, 7)

    struct TestSrcLoc: Equatable {
        var filename: String
        var line: UInt64
        var column: UInt64
        var offset: UInt64

        init(filename: String, line: UInt64, column: UInt64, offset: UInt64) {
            self.filename = filename
            self.line = line
            self.column = column
            self.offset = offset
        }

        init(_ original: SerializedDiagnostics.SourceLocation) {
            self.filename = original.filename
            self.line = original.line
            self.column = original.column
            self.offset = original.offset
        }
    }

    struct TestDiag {
        var text: String
        var level: SerializedDiagnostics.Diagnostic.Level
        var location: TestSrcLoc?
        var category: String?
        var flag: String?

    }

    let expectedResults = [
        TestDiag(text: "type 'A' does not conform to protocol 'P'",
                 level: .error,
                 location: TestSrcLoc(filename: "test.swift",
                                      line: 5, column: 7, offset: 35)),
        TestDiag(text: "candidate is 'async', but protocol requirement is not",
                 level: .note,
                 location: TestSrcLoc(filename: "test.swift",
                                      line: 6, column: 10, offset: 51)),
        TestDiag(text: "do you want to add protocol stubs?",
                 level: .note,
                 location: TestSrcLoc(filename: "test.swift",
                                      line: 5, column: 7, offset: 35)),
        TestDiag(text: "initialization of immutable value 'a' was never used",
                 level: .warning,
                 location: TestSrcLoc(filename: "test.swift",
                                      line: 7, column: 13, offset: 75)),
        TestDiag(text: "consider replacing with '_' or removing it",
                 level: .note,
                 location: TestSrcLoc(filename: "test.swift",
                                      line: 7, column: 13, offset: 75)),
        TestDiag(text: "initialization of immutable value 'b' was never used",
                 level: .warning,
                 location: TestSrcLoc(filename: "test.swift",
                                      line: 8, column: 13, offset: 94)),
        TestDiag(text: "consider replacing with '_' or removing it",
                 level: .note,
                 location: TestSrcLoc(filename: "test.swift",
                                      line: 8, column: 13, offset: 94))
    ]

    for case let (diag, expected) in zip(serializedDiags.diagnostics,
        expectedResults) {
        XCTAssertEqual(diag.text, expected.text, "Mismatched Diagnostic Text")
        XCTAssertEqual(diag.level, expected.level, "Mismatched Diagnostic Level")

        XCTAssertEqual((diag.location == nil), (expected.location == nil), "Unexpected Diagnostic Location")
        if let diagLoc = diag.location, let expectedLoc = expected.location {
            XCTAssertEqual(TestSrcLoc(diagLoc), expectedLoc, "Mismatched Diagnostic Location")
        }
    }
  }

  func testReadSwiftSerializedDiags() throws {
    let serializedDiagnosticsPath = AbsolutePath(#file).parentDirectory
        .appending(components: "Inputs", "serialized.dia")
    let contents = try localFileSystem.readFileContents(serializedDiagnosticsPath)
    let serializedDiags = try SerializedDiagnostics(bytes: contents)

    XCTAssertEqual(serializedDiags.versionNumber, 1)
    XCTAssertEqual(serializedDiags.diagnostics.count, 17)

    let one = serializedDiags.diagnostics[5]
    XCTAssertEqual(one.text, "expected ',' separator")
    XCTAssertEqual(one.level, .error)
    XCTAssertEqual(one.location?.filename.hasSuffix("/StoreSearchCoordinator.swift"), true)
    XCTAssertEqual(one.location?.line, 21)
    XCTAssertEqual(one.location?.column, 69)
    XCTAssertEqual(one.location?.offset, 0)
    XCTAssertNil(one.category)
    XCTAssertNil(one.flag)
    XCTAssertEqual(one.ranges.count, 0)
    XCTAssertEqual(one.fixIts.count, 1)
    XCTAssertEqual(one.fixIts[0].text, ",")
    XCTAssertEqual(one.fixIts[0].start, one.fixIts[0].end)
    XCTAssertEqual(one.fixIts[0].start.filename.hasSuffix("/StoreSearchCoordinator.swift"), true)
    XCTAssertEqual(one.fixIts[0].start.line, 21)
    XCTAssertEqual(one.fixIts[0].start.column, 69)
    XCTAssertEqual(one.fixIts[0].start.offset, 0)

    let two = serializedDiags.diagnostics[16]
    XCTAssertEqual(two.text, "use of unresolved identifier 'DispatchQueue'")
    XCTAssertEqual(two.level, .error)
    XCTAssertEqual(two.location?.filename.hasSuffix("/Observable.swift"), true)
    XCTAssertEqual(two.location?.line, 34)
    XCTAssertEqual(two.location?.column, 13)
    XCTAssertEqual(two.location?.offset, 0)
    XCTAssertNil(two.category)
    XCTAssertNil(two.flag)
    XCTAssertEqual(two.ranges.count, 1)
    XCTAssertEqual(two.ranges[0].0.filename.hasSuffix("/Observable.swift"), true)
    XCTAssertEqual(two.ranges[0].0.line, 34)
    XCTAssertEqual(two.ranges[0].0.column, 13)
    XCTAssertEqual(two.ranges[0].0.offset, 0)
    XCTAssertEqual(two.ranges[0].1.filename.hasSuffix("/Observable.swift"), true)
    XCTAssertEqual(two.ranges[0].1.line, 34)
    XCTAssertEqual(two.ranges[0].1.column, 26)
    XCTAssertEqual(two.ranges[0].1.offset, 0)
    XCTAssertEqual(two.fixIts.count, 0)
  }

  func testReadDiagsWithNoLocation() throws {
    let serializedDiagnosticsPath = AbsolutePath(#file).parentDirectory
        .appending(components: "Inputs", "no-location.dia")
    let contents = try localFileSystem.readFileContents(serializedDiagnosticsPath)
    let serializedDiags = try SerializedDiagnostics(bytes: contents)

    XCTAssertEqual(serializedDiags.versionNumber, 2)
    XCTAssertEqual(serializedDiags.diagnostics.count, 1)

    let diag = serializedDiags.diagnostics[0]
    XCTAssertEqual(diag.text, "API breakage: func foo() has been removed")
    XCTAssertEqual(diag.level, .error)
    XCTAssertNil(diag.location)
    XCTAssertEqual(diag.category, "api-digester-breaking-change")
    XCTAssertNil(diag.flag)
    XCTAssertEqual(diag.ranges.count, 0)
    XCTAssertEqual(diag.fixIts.count, 0)
  }

  func testReadClangSerializedDiags() throws {
    let serializedDiagnosticsPath = AbsolutePath(#file).parentDirectory
        .appending(components: "Inputs", "clang.dia")
    let contents = try localFileSystem.readFileContents(serializedDiagnosticsPath)
    let serializedDiags = try SerializedDiagnostics(bytes: contents)

    XCTAssertEqual(serializedDiags.versionNumber, 1)
    XCTAssertEqual(serializedDiags.diagnostics.count, 4)

    let one = serializedDiags.diagnostics[1]
    XCTAssertEqual(one.text, "values of type 'NSInteger' should not be used as format arguments; add an explicit cast to 'long' instead")
    XCTAssertEqual(one.level, .warning)
    XCTAssertEqual(one.location?.line, 252)
    XCTAssertEqual(one.location?.column, 137)
    XCTAssertEqual(one.location?.offset, 10046)
    XCTAssertEqual(one.category, "Format String Issue")
    XCTAssertEqual(one.flag, "format")
    XCTAssertEqual(one.ranges.count, 4)
    XCTAssertEqual(one.fixIts.count, 2)
  }
}
