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

    func testBufferedWriter() {
        let writer = BitstreamWriter()

        // Make sure we only blit 32 bits at a time.
        XCTAssertTrue(writer.isEmpty)
        XCTAssertEqual(writer.bufferOffset, 0)
        XCTAssertEqual(writer.bitNumber, 0)
        writer.writeASCII("B")
        XCTAssertEqual(writer.bufferOffset, 0)
        XCTAssertEqual(writer.bitNumber, 8)
        writer.writeASCII("I")
        XCTAssertEqual(writer.bufferOffset, 0)
        XCTAssertEqual(writer.bitNumber, 16)
        writer.writeASCII("T")
        XCTAssertEqual(writer.bufferOffset, 0)
        XCTAssertEqual(writer.bitNumber, 24)
        writer.writeASCII("S")
        XCTAssertEqual(writer.bufferOffset, 4)
        XCTAssertEqual(writer.bitNumber, 32)
    }

    func testWriteEquivalence() {
        let literalWriter = BitstreamWriter()
        XCTAssertTrue(literalWriter.isEmpty)
        literalWriter.writeBlob([], includeSize: false)
        XCTAssertTrue(literalWriter.isEmpty)

        do {
            literalWriter.writeASCII("B")
            literalWriter.writeASCII("I")
            literalWriter.writeASCII("T")
            literalWriter.writeASCII("S")
        }

        let stringWriter = BitstreamWriter()
        do {
            stringWriter.writeBlob("BITS".map { $0.asciiValue! }, includeSize: false)
        }

        XCTAssertEqual(literalWriter.data, stringWriter.data)
    }

    func testWriteAlignment() {
        do {
            let writer = BitstreamWriter()
            XCTAssertTrue(writer.isEmpty)
            writer.alignIfNeeded()
            XCTAssertTrue(writer.isEmpty)
        }

        do {
            let writer = BitstreamWriter()
            XCTAssertTrue(writer.isEmpty)
            writer.writeASCII("B")
            writer.alignIfNeeded()
            XCTAssertEqual(writer.data, [
                ("B" as Character).asciiValue!,
                0, 0, 0
            ])
        }

        do {
            let writer = BitstreamWriter()
            XCTAssertTrue(writer.isEmpty)
            writer.writeASCII("B")
            writer.writeASCII("I")
            writer.alignIfNeeded()
            XCTAssertEqual(writer.data, [
                ("B" as Character).asciiValue!,
                ("I" as Character).asciiValue!,
                0, 0
            ])
        }

        do {
            let writer = BitstreamWriter()
            XCTAssertTrue(writer.isEmpty)
            writer.writeASCII("B")
            writer.writeASCII("I")
            writer.writeASCII("T")
            writer.alignIfNeeded()
            XCTAssertEqual(writer.data, [
                ("B" as Character).asciiValue!,
                ("I" as Character).asciiValue!,
                ("T" as Character).asciiValue!,
                0
            ])
        }

        do {
            let writer = BitstreamWriter()
            XCTAssertTrue(writer.isEmpty)
            writer.writeASCII("B")
            writer.writeASCII("I")
            writer.writeASCII("T")
            writer.writeASCII("S")
            writer.alignIfNeeded()
            XCTAssertEqual(writer.data, [
                ("B" as Character).asciiValue!,
                ("I" as Character).asciiValue!,
                ("T" as Character).asciiValue!,
                ("S" as Character).asciiValue!,
            ])
        }
    }

    func testRoundTrip() throws {
        enum RoundTripRecordID: UInt8 {
            case version = 1
            case blob    = 2
        }

        struct RoundTripVisitor: BitstreamVisitor {
            var log: [String] = []

            func validate(signature: Bitcode.Signature) throws {
                XCTAssertEqual(signature, Bitcode.Signature(string: "BITS"))
            }

            mutating func shouldEnterBlock(id: UInt64) throws -> Bool {
                return true
            }

            mutating func didExitBlock() throws {}

            mutating func visit(record: BitcodeElement.Record) throws {
                switch record.id {
                case UInt64(RoundTripRecordID.version.rawValue):
                    XCTAssertEqual(Array(record.fields), [ 25 ]) // version
                    guard case .none = record.payload else {
                        XCTFail("Unexpected payload in metadata record!")
                        return
                    }
                case UInt64(RoundTripRecordID.blob.rawValue):
                    XCTAssertEqual(Array(record.fields), [
                        42,
                        43,
                        44,
                        45,
                    ])
                    guard case .none = record.payload else {
                        XCTFail("Unexpected payload in blob record!")
                        return
                    }
                default:
                    XCTFail("Unexpected record ID \(record.id)")
                }
            }
        }

        let writer = BitstreamWriter()
        writer.writeASCII("B")
        writer.writeASCII("I")
        writer.writeASCII("T")
        writer.writeASCII("S")

        var versionAbbrev: Bitstream.AbbreviationID? = nil
        var dataBlobAbbrev: Bitstream.AbbreviationID? = nil
        writer.writeBlockInfoBlock {
            self.emitBlockID(.metadata, named: "Meta", to: writer)
            self.emitRecordID(RoundTripRecordID.version, named: "Version", to: writer)

            versionAbbrev = writer.defineBlockInfoAbbreviation(.metadata, .init([
                .literalCode(RoundTripRecordID.version),
                .fixed(bitWidth: 32)
            ]))

            emitBlockID(.data, named: "Data", to: writer)
            emitRecordID(RoundTripRecordID.blob, named: "DataBlob", to: writer)

            dataBlobAbbrev = writer.defineBlockInfoAbbreviation(.data, .init([
                .literalCode(RoundTripRecordID.blob),
                .fixed(bitWidth: 10), // File ID
                .fixed(bitWidth: 32), // Line
                .fixed(bitWidth: 32), // Column
                .fixed(bitWidth: 32), // Offset
            ]))
        }

        writer.writeBlock(.metadata, newAbbrevWidth: 3) {
            writer.writeRecord(versionAbbrev!) {
                $0.append(RoundTripRecordID.version)
                $0.append(25 as UInt32)
            }
        }

        writer.writeBlock(.data, newAbbrevWidth: 3) {
            writer.writeRecord(dataBlobAbbrev!) {
                $0.append(RoundTripRecordID.blob)
                $0.append(42 as UInt32)
                $0.append(43 as UInt32)
                $0.append(44 as UInt32)
                $0.append(45 as UInt32)
            }
        }

        var visitor = RoundTripVisitor()
        try Bitcode.read(bytes: ByteString(writer.data), using: &visitor)
    }

    func testSimpleRecordWrite() {
        let recordWriter = BitstreamWriter()
        recordWriter.withSubBlock(.metadata, abbreviationBitWidth: 2) {
            recordWriter.writeRecord(Bitstream.BlockInfoCode.setRecordName) {
                $0.append(Bitstream.AbbreviationID.mockAbbreviation)
            }
        }
        XCTAssertEqual(recordWriter.data, [
            UInt8(Bitstream.AbbreviationID.enterSubblock.rawValue) | (UInt8(Bitstream.BlockID.metadata.rawValue) << 2),
            UInt8(2 << 2),
            UInt8(0), UInt8(0),
            // now 32-bit aligned, the length we back-patched comes up next
            UInt8(1), UInt8(0), UInt8(0), UInt8(0),
            // Still 32-bit aligned, now here's the record data
            UInt8(Bitstream.AbbreviationID.unabbreviatedRecord.rawValue)
                | UInt8(Bitstream.BlockInfoCode.setRecordName.rawValue << 2),
            UInt8(1), // record length of 1 - which is just the ID field
            UInt8(1), // record ID itself - which is 0b00001000 but we're
                      // 14 bits in by the time we get here and writing 6 bits,
                      // so we're going to mush in the end marker (0b00)
            UInt8(0), // Then align to 32 bits.
        ])
    }

    func emitBlockID(_ id: Bitstream.BlockID, named name: String, to stream: BitstreamWriter) {
        stream.writeRecord(Bitstream.BlockInfoCode.setBID) {
            $0.append(id)
        }

        stream.writeRecord(Bitstream.BlockInfoCode.blockName) {
            $0.append(name)
        }
    }

    func emitRecordID<CodeType>(_ id: CodeType, named name: String, to stream: BitstreamWriter)
        where CodeType: RawRepresentable, CodeType.RawValue: UnsignedInteger & ExpressibleByIntegerLiteral
    {
        stream.writeRecord(Bitstream.BlockInfoCode.setRecordName) {
            $0.append(id)
            $0.append(name)
        }
    }

    func testComplexRecordWrite() {
        enum DiagnosticRecordID: UInt8 {
            case version        = 1
            case diagnostic     = 2
            case sourceRange    = 3
            case diagnosticFlag = 4
            case category       = 5
            case filename       = 6
            case fixIt          = 7
        }


        var abbreviations = [Bitstream.AbbreviationID]()

        let recordWriter = BitstreamWriter()
        recordWriter.writeASCII("D")
        recordWriter.writeASCII("I")
        recordWriter.writeASCII("A")
        recordWriter.writeASCII("G")
        recordWriter.writeBlockInfoBlock {
            self.emitBlockID(.metadata, named: "Meta", to: recordWriter)
            self.emitRecordID(DiagnosticRecordID.version, named: "Version", to: recordWriter)

            abbreviations.append(recordWriter.defineBlockInfoAbbreviation(.metadata, .init([
                .literalCode(DiagnosticRecordID.version),
                .fixed(bitWidth: 32)
            ])))

            emitBlockID(.diagnostics, named: "Diag", to: recordWriter)
            emitRecordID(DiagnosticRecordID.diagnostic, named: "DiagInfo", to: recordWriter)
            emitRecordID(DiagnosticRecordID.sourceRange, named: "SrcRange", to: recordWriter)
            emitRecordID(DiagnosticRecordID.category, named: "CatName", to: recordWriter)
            emitRecordID(DiagnosticRecordID.diagnosticFlag, named: "DiagFlag", to: recordWriter)
            emitRecordID(DiagnosticRecordID.filename, named: "FileName", to: recordWriter)
            emitRecordID(DiagnosticRecordID.fixIt, named: "FixIt", to: recordWriter)

            let sourceLocationOperands: [Bitstream.Abbreviation.Operand] = [
                .fixed(bitWidth: 10), // File ID
                .fixed(bitWidth: 32), // Line
                .fixed(bitWidth: 32), // Column
                .fixed(bitWidth: 32), // Offset
            ]

            abbreviations.append(recordWriter.defineBlockInfoAbbreviation(.diagnostics, .init([
                .literalCode(DiagnosticRecordID.diagnostic),
                .fixed(bitWidth: 3)   // Diag level.
            ] + sourceLocationOperands + [
                .fixed(bitWidth: 10), // Category.
                .fixed(bitWidth: 10), // Mapped Diag ID.
                .fixed(bitWidth: 16), // Text size.
                .blob                 // Diagnostic text.
            ])))

            abbreviations.append(recordWriter.defineBlockInfoAbbreviation(.diagnostics, .init([
                .literalCode(DiagnosticRecordID.category),
                .fixed(bitWidth: 16), // Category ID
                .fixed(bitWidth: 8),  // Text size
                .blob                 // Category text
            ])))

            abbreviations.append(recordWriter.defineBlockInfoAbbreviation(.diagnostics, .init([
                .literalCode(DiagnosticRecordID.sourceRange)
            ] + sourceLocationOperands + sourceLocationOperands)))

            abbreviations.append(recordWriter.defineBlockInfoAbbreviation(.diagnostics, .init([
              .literalCode(DiagnosticRecordID.diagnosticFlag),
              .fixed(bitWidth: 10), // Mapped Diag ID
              .fixed(bitWidth: 16), // Text size
              .blob                 // Flag name text
            ])))

            abbreviations.append(recordWriter.defineBlockInfoAbbreviation(.diagnostics, .init([
              .literalCode(DiagnosticRecordID.filename),
              .fixed(bitWidth: 10), // Mapped File ID
              .fixed(bitWidth: 32), // Size
              .fixed(bitWidth: 32), // Modification time.
              .fixed(bitWidth: 16), // Text size.
              .blob                 // File name text
            ])))

            abbreviations.append(recordWriter.defineBlockInfoAbbreviation(.diagnostics, .init([
                .literalCode(DiagnosticRecordID.fixIt)
            ] + sourceLocationOperands + sourceLocationOperands + [
                .fixed(bitWidth: 16), // Text size
                .blob                // FixIt Text
            ])))
        }

        XCTAssertEqual(recordWriter.data, [
                        68, 73, 65, 71, // 'DIAG'
                        1, 8, 0, 0,
                        48, 0, 0, 0,
                        7, 1, 178, 64,
                        180, 66, 57, 208,
                        67, 56, 60, 32,
                        129, 45, 148, 131,
                        60, 204, 67, 58,
                        188, 131, 59, 28,
                        4, 136, 98, 128,
                        64, 113, 16, 36,
                        11, 4, 41, 164,
                        67, 56, 156, 195,
                        67, 34, 144, 66,
                        58, 132, 195, 57,
                        164, 130, 59, 152,
                        195, 59, 60, 36,
                        195, 44, 200, 195,
                        56, 200, 66, 56,
                        184, 195, 57, 148,
                        195, 3, 82, 140,
                        66, 56, 208, 131,
                        43, 132, 67, 59,
                        148, 195, 67, 66,
                        144, 66, 58, 132,
                        195, 57, 152, 2,
                        59, 132, 195, 57,
                        60, 36, 134, 41,
                        164, 3, 59, 148,
                        131, 43, 132, 67,
                        59, 148, 195, 131,
                        113, 152, 66, 58,
                        224, 67, 42, 208,
                        195, 65, 144, 168,
                        10, 200, 16, 37,
                        80, 8, 20, 2,
                        133, 40, 81, 2,
                        131, 74, 22, 8,
                        12, 130, 212, 116,
                        64, 148, 64, 33,
                        80, 8, 20, 162,
                        4, 10, 129, 66,
                        160, 144, 36, 16,
                        37, 48, 168, 166,
                        129, 40, 129, 66,
                        160, 16, 24, 212,
                        245, 64, 148, 64,
                        33, 80, 8, 20,
                        162, 4, 10, 129,
                        66, 160, 16, 24,
                        20, 0, 0, 0])
    }
}

extension Bitstream.BlockID {
    static let metadata     = Self.firstApplicationID
    static let diagnostics  = Self.firstApplicationID + 1
    static let data         = Self.firstApplicationID + 2
}

extension Bitstream.AbbreviationID {
    static let mockAbbreviation          = Self.firstApplicationID
}

extension Bitstream.Abbreviation.Operand {
    /// Turns a literal value of a RawRepresentable type into a literal abbrev.
    static func literalCode<CodeType>(
        _ code: CodeType
    ) -> Bitstream.Abbreviation.Operand
        where CodeType: RawRepresentable, CodeType.RawValue: UnsignedInteger & ExpressibleByIntegerLiteral
    {
        return .literal(numericCast(code.rawValue))
    }
}
