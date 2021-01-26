/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2020-2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Represents the contents of a file encoded using the
/// [LLVM bitstream container format](https://llvm.org/docs/BitCodeFormat.html#bitstream-container-format)
public struct Bitcode {
  public let signature: Signature
  public let elements: [BitcodeElement]
  public let blockInfo: [UInt64: BlockInfo]
}

public enum BitcodeElement {
  public struct Block {
    public var id: UInt64
    public var elements: [BitcodeElement]
  }

  public struct Record {
    public enum Payload {
      case none
      case array([UInt64])
      case char6String(String)
      case blob(Data)
    }

    public var id: UInt64
    public var fields: [UInt64]
    public var payload: Payload
  }

  case block(Block)
  case record(Record)
}

public struct BlockInfo {
  public var name: String = ""
  public var recordNames: [UInt64: String] = [:]
}

extension Bitcode {
  public struct Signature: Equatable {
    private var value: UInt32

    public init(value: UInt32) {
      self.value = value
    }

    public init(string: String) {
      precondition(string.utf8.count == 4)
      var result: UInt32 = 0
      for byte in string.utf8.reversed() {
        result <<= 8
        result |= UInt32(byte)
      }
      self.value = result
    }
  }
}

/// A visitor which receives callbacks while reading a bitstream.
public protocol BitstreamVisitor {
  /// Customization point to validate a bitstream's signature or "magic number".
  func validate(signature: Bitcode.Signature) throws
  /// Called when a new block is encountered. Return `true` to enter the block
  /// and read its contents, or `false` to skip it.
  mutating func shouldEnterBlock(id: UInt64) throws -> Bool
  /// Called when a block is exited.
  mutating func didExitBlock() throws
  /// Called whenever a record is encountered.
  mutating func visit(record: BitcodeElement.Record) throws
}

/// A top-level namespace for all bitstream
public enum Bitstream {}

extension Bitstream {
  public struct Abbreviation {
    public enum Operand {
      /// A literal value (emitted as a VBR8 field).
      case literal(UInt64)

      /// A fixed-width field.
      case fixed(bitWidth: UInt8)

      /// A VBR-encoded value with the provided chunk width.
      case vbr(chunkBitWidth: UInt8)

      /// An array of values. This expects another operand encoded
      /// directly after indicating the element type.
      /// The array will begin with a vbr6 value indicating the length of
      /// the following array.
      indirect case array(Operand)

      /// A char6-encoded ASCII character.
      case char6

      /// Emitted as a vbr6 value, padded to a 32-bit boundary and then
      /// an array of 8-bit objects.
      case blob

      var isPayload: Bool {
        switch self {
        case .array, .blob: return true
        case .literal, .fixed, .vbr, .char6: return false
        }
      }

      /// Whether this case is the `literal` case.
      var isLiteral: Bool {
        if case .literal = self { return true }
        return false
      }

      /// The llvm::BitCodeAbbrevOp::Encoding value this
      /// enum case represents.
      /// - note: Must match the encoding in
      ///         http://llvm.org/docs/BitCodeFormat.html#define-abbrev-encoding
      var encodedKind: UInt8 {
        switch self {
        case .literal(_): return 0
        case .fixed(_): return 1
        case .vbr(_): return 2
        case .array: return 3
        case .char6: return 4
        case .blob: return 5
        }
      }
    }

    public var operands: [Operand] = []

    public init(_ operands: [Operand]) {
      self.operands = operands
    }
  }
}

extension Bitstream {
  public struct BlockID: RawRepresentable, Equatable, Hashable, Comparable, Identifiable {
    public var rawValue: UInt8

    public init(rawValue: UInt8) {
      self.rawValue = rawValue
    }

    public static let blockInfo = Self(rawValue: 0)
    public static let firstApplicationID = Self(rawValue: 8)

    public var id: UInt8 {
      self.rawValue
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.rawValue < rhs.rawValue
    }

    public static func + (lhs: Self, rhs: UInt8) -> Self {
      return BlockID(rawValue: lhs.rawValue + rhs)
    }
  }
}

extension Bitstream {
  public struct AbbreviationID: RawRepresentable, Equatable, Hashable, Comparable, Identifiable {
    public var rawValue: UInt64

    public init(rawValue: UInt64) {
      self.rawValue = rawValue
    }

    public static let endBlock = Self(rawValue: 0)
    public static let enterSubblock = Self(rawValue: 1)
    public static let defineAbbreviation = Self(rawValue: 2)
    public static let unabbreviatedRecord = Self(rawValue: 3)
    /// The first application-defined abbreviation ID.
    public static let firstApplicationID = Self(rawValue: 4)

    public var id: UInt64 {
      self.rawValue
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.rawValue < rhs.rawValue
    }

    public static func + (lhs: Self, rhs: UInt64) -> Self {
      return AbbreviationID(rawValue: lhs.rawValue + rhs)
    }
  }
}
