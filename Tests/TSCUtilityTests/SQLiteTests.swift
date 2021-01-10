/*
 This source file is part of the Swift.org open source project

 Copyright 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import TSCBasic
import TSCTestSupport
@testable import TSCUtility
import XCTest

class SQLiteTests: XCTestCase {
    func testFile() throws {
        try testWithTemporaryDirectory { tmpdir in
            let path = tmpdir.appending(component: "test.db")
            let db = try SQLite(location: .path(path))
            defer { XCTAssertNoThrow(try db.close()) }

            try validateDB(db: db)

            XCTAssertTrue(localFileSystem.exists(path), "expected file to be written")
        }
    }

    func testTemp() throws {
        let db = try SQLite(location: .temporary)
        defer { XCTAssertNoThrow(try db.close()) }

        try self.validateDB(db: db)
    }

    func testMemory() throws {
        let db = try SQLite(location: .memory)
        defer { XCTAssertNoThrow(try db.close()) }

        try self.validateDB(db: db)
    }

    func validateDB(db: SQLite, file: StaticString = #file, line: UInt = #line) throws {
        let tableName = UUID().uuidString
        let count = Int.random(in: 50 ... 100)

        try db.exec(query: "CREATE TABLE \"\(tableName)\" (ID INT PRIMARY KEY, NAME STRING);")

        for index in 0 ..< count {
            let statement = try db.prepare(query: "INSERT INTO \"\(tableName)\" VALUES (?, ?);")
            defer { XCTAssertNoThrow(try statement.finalize(), file: file, line: line) }
            try statement.bind([.int(index), .string(UUID().uuidString)])
            try statement.step()
        }

        do {
            let statement = try db.prepare(query: "SELECT * FROM \"\(tableName)\";")
            defer { XCTAssertNoThrow(try statement.finalize(), file: file, line: line) }
            var results = [SQLite.Row]()
            while let row = try statement.step() {
                results.append(row)
            }
            XCTAssertEqual(results.count, count, "expected results count to match", file: file, line: line)
        }

        do {
            let statement = try db.prepare(query: "SELECT * FROM \"\(tableName)\" where ID = ?;")
            defer { XCTAssertNoThrow(try statement.finalize(), file: file, line: line) }
            try statement.bind([.int(Int.random(in: 0 ..< count))])
            let row = try statement.step()
            XCTAssertNotNil(row, "expected results")
        }
    }

    func testConfiguration() throws {
        var configuration = SQLite.Configuration()

        let timeout = Int32.random(in: 1000 ... 10000)
        configuration.busyTimeoutMilliseconds = timeout
        XCTAssertEqual(configuration.busyTimeoutMilliseconds, timeout)
        XCTAssertEqual(configuration._busyTimeoutSeconds, Int32(Double(timeout) / 1000))

        let maxSizeInBytes = Int.random(in: 1000 ... 10000)
        configuration.maxSizeInBytes = maxSizeInBytes
        XCTAssertEqual(configuration.maxSizeInBytes, maxSizeInBytes)
        XCTAssertEqual(configuration.maxSizeInMegabytes, maxSizeInBytes / (1024 * 1024))
    }

    func testMaxSize() throws {
        var configuration = SQLite.Configuration()
        configuration.maxSizeInBytes = 1024
        let db = try SQLite(location: .memory, configuration: configuration)
        defer { XCTAssertNoThrow(try db.close()) }

        func generateData() throws {
            let tableName = UUID().uuidString
            try db.exec(query: "CREATE TABLE \"\(tableName)\" (ID INT PRIMARY KEY, NAME STRING);")
            for index in 0 ..< 1024 {
                let statement = try db.prepare(query: "INSERT INTO \"\(tableName)\" VALUES (?, ?);")
                defer { XCTAssertNoThrow(try statement.finalize()) }
                try statement.bind([.int(index), .string(UUID().uuidString)])
                try statement.step()
            }
        }

        XCTAssertThrowsError(try generateData(), "expected error", { error in
            XCTAssertEqual(error as? SQLite.Errors, .databaseFull, "Expected 'database or disk is full' error")
        })
    }
}
