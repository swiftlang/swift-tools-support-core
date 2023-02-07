/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import protocol Foundation.CustomNSError
import var Foundation.NSLocalizedDescriptionKey
import TSCBasic

/// Triple - Helper class for working with Destination.target values
///
/// Used for parsing values such as x86_64-apple-macosx10.10 into
/// set of enums. For os/arch/abi based conditions in build plan.
///
/// @see Destination.target
/// @see https://github.com/apple/swift-llvm/blob/stable/include/llvm/ADT/Triple.h
///
public struct Triple: Encodable, Equatable {
    public let tripleString: String

    public let arch: Arch
    public let vendor: Vendor
    public let os: OS
    public let abi: ABI
    public let osVersion: String?
    public let abiVersion: String?

    public enum Error: Swift.Error {
        case badFormat(triple: String)
        case unknownArch(arch: String)
        case unknownOS(os: String)
    }

    public enum ARMCore: String, Encodable, CaseIterable {
        case a = "a"
        case r = "r"
        case m = "m"
        case k = "k"
        case s = "s"
    }

    public enum Arch: Encodable {
        case x86_64
        case x86_64h
        case i686
        case powerpc
        case powerpc64le
        case s390x
        case aarch64
        case amd64
        case armv7(core: ARMCore?)
        case armv6
        case armv5
        case arm
        case arm64
        case arm64e
        case wasm32
        case riscv64
        case mips
        case mipsel
        case mips64
        case mips64el
    }

    public enum Vendor: String, Encodable {
        case unknown
        case apple
    }

    public enum OS: String, Encodable, CaseIterable {
        case darwin
        case macOS = "macosx"
        case linux
        case windows
        case wasi
        case openbsd
    }

    public enum ABI: Encodable, Equatable, RawRepresentable {
        case unknown
        case android
        case other(name: String)

        public init?(rawValue: String) {
            if rawValue.hasPrefix(ABI.android.rawValue) {
                self = .android
            } else if let version = rawValue.firstIndex(where: { $0.isNumber }) {
                self = .other(name: String(rawValue[..<version]))
            } else {
                self = .other(name: rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .android: return "android"
            case .other(let name): return name
            case .unknown: return "unknown"
            }
        }

        public static func ==(lhs: ABI, rhs: ABI) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown):
                return true
            case (.android, .android):
                return true
            case let (.other(lhsName), .other(rhsName)):
                return lhsName == rhsName
            default:
                return false
            }
        }
    }

    public init(_ string: String) throws {
        let components = string.split(separator: "-").map(String.init)

        guard components.count == 3 || components.count == 4 else {
            throw Error.badFormat(triple: string)
        }

        guard let arch = Triple.parseArch(components[0]) else {
            throw Error.unknownArch(arch: components[0])
        }

        let vendor = Vendor(rawValue: components[1]) ?? .unknown

        guard let os = Triple.parseOS(components[2]) else {
            throw Error.unknownOS(os: components[2])
        }

        let osVersion = Triple.parseVersion(components[2])

        let abi = components.count > 3 ? Triple.ABI(rawValue: components[3]) : nil
        let abiVersion = components.count > 3 ? Triple.parseVersion(components[3]) : nil

        self.tripleString = string
        self.arch = arch
        self.vendor = vendor
        self.os = os
        self.osVersion = osVersion
        self.abi = abi ?? .unknown
        self.abiVersion = abiVersion
    }

    fileprivate static func parseArch(_ string: String) -> Arch? {
        let candidates: [String:Arch] = [
            "x86_64h": .x86_64h,
            "x86_64": .x86_64,
            "i686": .i686,
            "powerpc64le": .powerpc64le,
            "s390x": .s390x,
            "aarch64": .aarch64,
            "amd64": .amd64,
            "armv7": .armv7(core: nil),
            "armv6": .armv6,
            "armv5": .armv5,
            "arm": .arm,
            "arm64": .arm64,
            "arm64e": .arm64e,
            "wasm32": .wasm32,
        ]
        if let match = candidates.first(where: { string.hasPrefix($0.key) })?.value {
            if case let .armv7(core: _) = match {
                if string.hasPrefix("armv7a") {
                    return .armv7(core: .a)
                } else if string.hasPrefix("armv7r") {
                    return .armv7(core: .r)
                } else if string.hasPrefix("armv7m") {
                    return .armv7(core: .m)
                } else if string.hasPrefix("armv7k") {
                    return .armv7(core: .k)
                } else if string.hasPrefix("armv7s") {
                    return .armv7(core: .s)
                }
                return .armv7(core: nil)
            }
            return match
        }
        return nil
    }

    fileprivate static func parseOS(_ string: String) -> OS? {
        var candidates =  OS.allCases.map{ (name: $0.rawValue, value: $0) }
        // LLVM target triples support this alternate spelling as well.
        candidates.append((name: "macos", value: .macOS))
        return candidates.first(where: { string.hasPrefix($0.name)  })?.value
    }

    fileprivate static func parseVersion(_ string: String) -> String? {
        let candidate = String(string.drop(while: { $0.isLetter }))
        if candidate != string && !candidate.isEmpty {
            return candidate
        }

        return nil
    }

    public func isAndroid() -> Bool {
        return os == .linux && abi == .android
    }

    public func isDarwin() -> Bool {
        return vendor == .apple || os == .macOS || os == .darwin
    }

    public func isLinux() -> Bool {
        return os == .linux
    }

    public func isWindows() -> Bool {
        return os == .windows
    }

    public func isWASI() -> Bool {
        return os == .wasi
    }

    public func isOpenBSD() -> Bool {
        return os == .openbsd
    }

    /// Returns the triple string for the given platform version.
    ///
    /// This is currently meant for Apple platforms only.
    public func tripleString(forPlatformVersion version: String) -> String {
        precondition(isDarwin())
        return String(self.tripleString.dropLast(self.osVersion?.count ?? 0)) + version
    }

    public static let macOS = try! Triple("x86_64-apple-macosx")

    /// Determine the versioned host triple using the Swift compiler.
    public static func getHostTriple(usingSwiftCompiler swiftCompiler: AbsolutePath) -> Triple {
        // Call the compiler to get the target info JSON.
        let compilerOutput: String
        do {
            let result = try Process.popen(args: swiftCompiler.pathString, "-print-target-info")
            compilerOutput = try result.utf8Output().spm_chomp()
        } catch {
            // FIXME: Remove the macOS special-casing once the latest version of Xcode comes with
            // a Swift compiler that supports -print-target-info.
            #if os(macOS)
                return .macOS
            #else
                fatalError("Failed to get target info (\(error))")
            #endif
        }

        // Parse the compiler's JSON output.
        let parsedTargetInfo: JSON
        do {
            parsedTargetInfo = try JSON(string: compilerOutput)
        } catch {
            fatalError("Failed to parse target info (\(error)).\nRaw compiler output: \(compilerOutput)")
        }
        // Get the triple string from the parsed JSON.
        let tripleString: String
        do {
            tripleString = try parsedTargetInfo.get("target").get("triple")
        } catch {
            fatalError("Target info does not contain a triple string (\(error)).\nTarget info: \(parsedTargetInfo)")
        }
        // Parse the triple string.
        do {
            return try Triple(tripleString)
        } catch {
            fatalError("Failed to parse triple string (\(error)).\nTriple string: \(tripleString)")
        }
    }

    public static func ==(lhs: Triple, rhs: Triple) -> Bool {
        return lhs.arch == rhs.arch && lhs.vendor == rhs.vendor && lhs.os == rhs.os && lhs.abi == rhs.abi && lhs.osVersion == rhs.osVersion && lhs.abiVersion == rhs.abiVersion
    }
}

extension Triple {
    /// The file prefix for dynamcic libraries
    public var dynamicLibraryPrefix: String {
        switch os {
        case .windows:
            return ""
        default:
            return "lib"
        }
    }

    /// The file extension for dynamic libraries (eg. `.dll`, `.so`, or `.dylib`)
    public var dynamicLibraryExtension: String {
        switch os {
        case .darwin, .macOS:
            return ".dylib"
        case .linux, .openbsd:
            return ".so"
        case .windows:
            return ".dll"
        case .wasi:
            return ".wasm"
        }
    }

    public var executableExtension: String {
      switch os {
      case .darwin, .macOS:
        return ""
      case .linux, .openbsd:
        return ""
      case .wasi:
        return ".wasm"
      case .windows:
        return ".exe"
      }
    }
    
    /// The file extension for static libraries.
    public var staticLibraryExtension: String {
        return ".a"
    }

    /// The file extension for Foundation-style bundle.
    public var nsbundleExtension: String {
        switch os {
        case .darwin, .macOS:
            return ".bundle"
        default:
            // See: https://github.com/apple/swift-corelibs-foundation/blob/master/Docs/FHS%20Bundles.md
            return ".resources"
        }
    }
}

extension Triple.Arch: CustomStringConvertible {
    public var description: String {
        switch self {
        case .x86_64:
            return "x86_64"
        case .x86_64h:
            return "x86_64h"
        case .i686:
            return "i686"
        case .powerpc64le:
            return "powerpc64le"
        case .s390x:
            return "s390x"
        case .aarch64:
            return "aarch64"
        case .amd64:
            return "amd64"
        case .armv7(.none):
            return "armv7"
        case let .armv7(core: .some(core)):
            return "armv7\(core)"
        case .armv6:
            return "armv6"
        case .armv5:
            return "armv5"
        case .arm:
            return "arm"
        case .arm64:
            return "arm64"
        case .arm64e:
            return "arm64e"
        case .wasm32:
            return "wasm32"
        }
    }
}

extension Triple.Arch: Equatable {
    public static func == (_ lhs: Triple.Arch, _ rhs: Triple.Arch) -> Bool {
        switch (lhs, rhs) {
            case (.x86_64, .x86_64):
                return true
            case (.x86_64h, .x86_64h):
                return true
            case (.i686, .i686):
                return true
            case (.powerpc64le, .powerpc64le):
                return true
            case (.s390x, .s390x):
                return true
            case (.armv7(.none), .armv7(.none)):
                return true
            case let (.armv7(.some(lhs)), .armv7(.some(rhs))) where lhs == rhs:
                return true
            case (.armv6, .armv6):
                return true
            case (.armv5, .armv5):
                return true
            case (.arm, .arm):
                return true
            case (.arm64, .arm64):
                return true
            case (.arm64e, .arm64e):
                return true
            case (.wasm32, .wasm32):
                return true
            default:
                return false
        }
    }
}

extension Triple.Error: CustomNSError {
    public var errorUserInfo: [String : Any] {
        return [NSLocalizedDescriptionKey: "\(self)"]
    }
}
