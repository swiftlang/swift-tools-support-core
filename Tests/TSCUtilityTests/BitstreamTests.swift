/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import TSCBasic
import TSCUtility
import XCTest

final class BitstreamTests: XCTestCase {
    func testBitstreamVisitor() throws {
        struct LoggingVisitor: BitstreamVisitor {
            var log: [String] = []

            func validate(signature: Bitcode.Signature) throws {}

            mutating func shouldEnterBlock(id: UInt64) throws -> Bool {
                log.append("entering block: \(id)")
                return true
            }

            mutating func didExitBlock() throws {
                log.append("exiting block")
            }

            mutating func visit(record: BitcodeElement.Record) throws {
                log.append("Record (id: \(record.id), fields: \(Array(record.fields)), payload: \(record.payload)")
            }
        }

        let bitstreamPath = AbsolutePath(#file).parentDirectory
            .appending(components: "Inputs", "serialized.dia")
        let contents = try localFileSystem.readFileContents(bitstreamPath)
        var visitor = LoggingVisitor()
        try Bitcode.read(bytes: contents, using: &visitor)
        XCTAssertEqual(visitor.log, [
            "entering block: 8",
            "Record (id: 1, fields: [1], payload: none",
            "exiting block",
            "entering block: 9",
            "Record (id: 6, fields: [1, 0, 0, 100], payload: blob(100 bytes)",
            "Record (id: 2, fields: [3, 1, 53, 28, 0, 0, 0, 34], payload: blob(34 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 2, fields: [3, 1, 53, 28, 0, 0, 0, 59], payload: blob(59 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 2, fields: [3, 1, 113, 1, 0, 0, 0, 38], payload: blob(38 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 2, fields: [3, 1, 113, 1, 0, 0, 0, 20], payload: blob(20 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 6, fields: [2, 0, 0, 98], payload: blob(98 bytes)",
            "Record (id: 2, fields: [3, 2, 21, 69, 0, 0, 0, 34], payload: blob(34 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 2, fields: [3, 2, 21, 69, 0, 0, 0, 22], payload: blob(22 bytes)",
            "Record (id: 7, fields: [2, 21, 69, 0, 2, 21, 69, 0, 1], payload: blob(1 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 2, fields: [3, 2, 21, 69, 0, 0, 0, 42], payload: blob(42 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 2, fields: [3, 2, 21, 69, 0, 0, 0, 22], payload: blob(22 bytes)",
            "Record (id: 7, fields: [2, 21, 69, 0, 2, 21, 69, 0, 1], payload: blob(1 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 6, fields: [3, 0, 0, 84], payload: blob(84 bytes)",
            "Record (id: 2, fields: [3, 3, 38, 28, 0, 0, 0, 34], payload: blob(34 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 2, fields: [3, 3, 38, 28, 0, 0, 0, 59], payload: blob(59 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 2, fields: [3, 3, 66, 1, 0, 0, 0, 38], payload: blob(38 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 2, fields: [3, 3, 66, 1, 0, 0, 0, 20], payload: blob(20 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 6, fields: [4, 0, 0, 93], payload: blob(93 bytes)",
            "Record (id: 2, fields: [3, 4, 15, 46, 0, 0, 0, 40], payload: blob(40 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 2, fields: [3, 4, 15, 46, 0, 0, 0, 22], payload: blob(22 bytes)",
            "Record (id: 7, fields: [4, 15, 46, 0, 4, 15, 46, 0, 1], payload: blob(1 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 2, fields: [3, 4, 15, 46, 0, 0, 0, 42], payload: blob(42 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 2, fields: [3, 4, 15, 46, 0, 0, 0, 22], payload: blob(22 bytes)",
            "Record (id: 7, fields: [4, 15, 46, 0, 4, 15, 46, 0, 1], payload: blob(1 bytes)",
            "exiting block",
            "entering block: 9",
            "Record (id: 6, fields: [5, 0, 0, 72], payload: blob(72 bytes)",
            "Record (id: 2, fields: [3, 5, 34, 13, 0, 0, 0, 44], payload: blob(44 bytes)",
            "Record (id: 3, fields: [5, 34, 13, 0, 5, 34, 26, 0], payload: none",
            "exiting block"
        ])
    }

    func testReadSkippingBlocks() throws {
        struct LoggingVisitor: BitstreamVisitor {
            var log: [String] = []

            func validate(signature: Bitcode.Signature) throws {}

            mutating func shouldEnterBlock(id: UInt64) throws -> Bool {
                log.append("skipping block: \(id)")
                return false
            }

            mutating func didExitBlock() throws {
                log.append("exiting block")
            }

            mutating func visit(record: BitcodeElement.Record) throws {
                log.append("visiting record")
            }
        }

        let bitstreamPath = AbsolutePath(#file).parentDirectory
            .appending(components: "Inputs", "serialized.dia")
        let contents = try localFileSystem.readFileContents(bitstreamPath)
        var visitor = LoggingVisitor()
        try Bitcode.read(bytes: contents, using: &visitor)
        XCTAssertEqual(visitor.log, ["skipping block: 8",
                                     "skipping block: 9",
                                     "skipping block: 9",
                                     "skipping block: 9",
                                     "skipping block: 9",
                                     "skipping block: 9",
                                     "skipping block: 9",
                                     "skipping block: 9",
                                     "skipping block: 9",
                                     "skipping block: 9",
                                     "skipping block: 9",
                                     "skipping block: 9",
                                     "skipping block: 9",
                                     "skipping block: 9",
                                     "skipping block: 9",
                                     "skipping block: 9",
                                     "skipping block: 9",
                                     "skipping block: 9"])
    }
}
