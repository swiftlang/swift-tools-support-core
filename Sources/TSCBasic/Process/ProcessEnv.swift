/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2019 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import TSCLibc

public struct ProcessEnvironmentKey {
  public let value: String
  public init(_ value: String) {
    self.value = value
  }
}

extension ProcessEnvironmentKey: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }
}

extension ProcessEnvironmentKey: Decodable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(String.self)
    }
}

extension ProcessEnvironmentKey: Equatable {
  public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
    #if os(Windows)
    // TODO: is this any faster than just doing a lowercased conversion and compare?
    return lhs.value.caseInsensitiveCompare(rhs.value) == .orderedSame
    #else
    return lhs.value == rhs.value
    #endif
  }
}

extension ProcessEnvironmentKey: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.init(value)
  }
}

extension ProcessEnvironmentKey: Hashable {
  public func hash(into hasher: inout Hasher) {
    #if os(Windows)
    self.value.lowercased().hash(into: &hasher)
    #else
    self.value.hash(into: &hasher)
    #endif
  }
}

extension ProcessEnvironmentKey: Sendable {}

public typealias ProcessEnvironmentBlock = [ProcessEnvironmentKey:String]
extension ProcessEnvironmentBlock {
  public init(_ dictionary: [String:String]) {
    self.init(uniqueKeysWithValues: dictionary.map { (ProcessEnvironmentKey($0.key), $0.value) })
  }
}

extension ProcessEnvironmentBlock: Sendable {}

/// Provides functionality related a process's environment.
public enum ProcessEnv {

    @available(*, deprecated, message: "Use `block` instead")
    public static var vars: [String:String] {
      Dictionary<String, String>(uniqueKeysWithValues: _vars.map { ($0.key.value, $0.value) })
    }

    /// Returns a dictionary containing the current environment.
    public static var block: ProcessEnvironmentBlock { _vars }

    private static var _vars = ProcessEnvironmentBlock(
        uniqueKeysWithValues: ProcessInfo.processInfo.environment.map {
            (ProcessEnvironmentBlock.Key($0.key), $0.value)
        }
    )

    /// Invalidate the cached env.
    public static func invalidateEnv() {
        _vars = ProcessEnvironmentBlock(
            uniqueKeysWithValues: ProcessInfo.processInfo.environment.map {
                (ProcessEnvironmentKey($0.key), $0.value)
            }
        )
    }

    /// Set the given key and value in the process's environment.
    public static func setVar(_ key: String, value: String) throws {
      #if os(Windows)
        guard TSCLibc._putenv("\(key)=\(value)") == 0 else {
            throw SystemError.setenv(Int32(GetLastError()), key)
        }
      #else
        guard TSCLibc.setenv(key, value, 1) == 0 else {
            throw SystemError.setenv(errno, key)
        }
      #endif
        invalidateEnv()
    }

    /// Unset the give key in the process's environment.
    public static func unsetVar(_ key: String) throws {
      #if os(Windows)
        guard TSCLibc._putenv("\(key)=") == 0 else {
            throw SystemError.unsetenv(Int32(GetLastError()), key)
        }
      #else
        guard TSCLibc.unsetenv(key) == 0 else {
            throw SystemError.unsetenv(errno, key)
        }
      #endif
        invalidateEnv()
    }

    /// `PATH` variable in the process's environment (`Path` under Windows).
    public static var path: String? {
        return block["PATH"]
    }

    /// The current working directory of the process.
    public static var cwd: AbsolutePath? {
        return localFileSystem.currentWorkingDirectory
    }

    /// Change the current working directory of the process.
    public static func chdir(_ path: AbsolutePath) throws {
        let path = path.pathString
      #if os(Windows)
        guard path.withCString(encodedAs: UTF16.self, {
            SetCurrentDirectoryW($0)
        }) else {
            throw SystemError.chdir(Int32(GetLastError()), path)
        }
      #else
        guard TSCLibc.chdir(path) == 0 else {
            throw SystemError.chdir(errno, path)
        }
      #endif
    }
}
