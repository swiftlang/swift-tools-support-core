/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2019 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import TSCLibc

public struct CaseInsensitiveString {
  public let value: String
  public init(_ value: String) {
    self.value = value
  }
}

extension CaseInsensitiveString: Equatable {
  public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
    // TODO: is this any faster than just doing a lowercased conversion and compare?
    return lhs.value.caseInsensitiveCompare(rhs.value) == .orderedSame
  }
}

extension CaseInsensitiveString: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.init(value)
  }
}

extension CaseInsensitiveString: Hashable {
  public func hash(into hasher: inout Hasher) {
    self.value.lowercased().hash(into: &hasher)
  }
}

extension CaseInsensitiveString: Sendable {}

#if os(Windows)
public typealias ProcessEnvironmentBlock = [CaseInsensitiveString:String]
extension ProcessEnvironmentBlock {
  public init(_ dictionary: [String:String]) {
    self.init(uniqueKeysWithValues: dictionary.map { (CaseInsensitiveString($0.key), $0.value) })
  }
}
#else
public typealias ProcessEnvironmentBlock = [String:String]
#endif

extension ProcessEnvironmentBlock: Sendable {}

/// Provides functionality related a process's environment.
public enum ProcessEnv {

    @available(*, deprecated, message: "Use `block` instead")
    public static var vars: [String:String] {
      #if os(Windows)
      Dictionary<String, String>(uniqueKeysWithValues: _vars.map { ($0.key.value, $0.value) })
      #else
      _vars
      #endif
    }

    /// Returns a dictionary containing the current environment.
    public static var block: ProcessEnvironmentBlock { _vars }

#if os(Windows)
    private static var _vars: ProcessEnvironmentBlock = {
        guard let lpwchEnvironment = GetEnvironmentStringsW() else { return [:] }
        defer { FreeEnvironmentStringsW(lpwchEnvironment) }
        var environment: ProcessEnvironmentBlock = [:]
        var pVariable = UnsafePointer<WCHAR>(lpwchEnvironment)
        while let entry = String.decodeCString(pVariable, as: UTF16.self) {
            if entry.result.isEmpty { break }
            let parts = entry.result.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                environment[CaseInsensitiveString(String(parts[0]))] = String(parts[1])
            }
            pVariable = pVariable.advanced(by: entry.result.utf16.count + 1)
        }
        return environment
    }()
#else
    private static var _vars = ProcessEnvironmentBlock(
        uniqueKeysWithValues: ProcessInfo.processInfo.environment.map {
            (ProcessEnvironmentBlock.Key($0.key), $0.value)
        }
    )
#endif

    /// Invalidate the cached env.
    public static func invalidateEnv() {
#if os(Windows)
        guard let lpwchEnvironment = GetEnvironmentStringsW() else {
          _vars = [:]
          return
        }
        defer { FreeEnvironmentStringsW(lpwchEnvironment) }

        var environment: ProcessEnvironmentBlock = [:]
        var pVariable = UnsafePointer<WCHAR>(lpwchEnvironment)
        while let entry = String.decodeCString(pVariable, as: UTF16.self) {
            if entry.result.isEmpty { break }
            let parts = entry.result.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                environment[CaseInsensitiveString(String(parts[0]))] = String(parts[1])
            }
            pVariable = pVariable.advanced(by: entry.result.utf16.count + 1)
        }
        _vars = environment
#else
        _vars = ProcessEnvironmentBlock(
            uniqueKeysWithValues: ProcessInfo.processInfo.environment.map {
                (CaseInsensitiveString($0.key), $0.value)
            }
        )
#endif
    }

    /// Set the given key and value in the process's environment.
    public static func setVar(_ key: String, value: String) throws {
      #if os(Windows)
        try key.withCString(encodedAs: UTF16.self) { pwszKey in
          try value.withCString(encodedAs: UTF16.self) { pwszValue in
            guard SetEnvironmentVariableW(pwszKey, pwszValue) else {
              throw SystemError.setenv(Int32(GetLastError()), key)
            }
          }
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
        guard key.withCString(encodedAs: UTF16.self, {
          SetEnvironmentVariableW($0, nil)
        }) else {
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
        guard path.withCString(encodedAs: UTF16.self, SetCurrentDirectoryW) else {
            throw SystemError.chdir(Int32(GetLastError()), path)
        }
      #else
        guard TSCLibc.chdir(path) == 0 else {
            throw SystemError.chdir(errno, path)
        }
      #endif
    }
}
