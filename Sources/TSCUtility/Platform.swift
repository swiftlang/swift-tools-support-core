/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import TSCBasic
import Foundation

/// Recognized Platform types.
@available(*, deprecated, message: "moved to SourceKit-LSP")
public enum Platform: Equatable {
    case android
    case darwin
    case linux(LinuxFlavor)
    case windows

    /// Recognized flavors of linux.
    public enum LinuxFlavor: Equatable {
        case debian
        case fedora
    }

    /// Lazily checked current platform.
    public static var currentPlatform = Platform.findCurrentPlatform(localFileSystem)

    /// Returns the cache directories used in Darwin.
    private static var darwinCacheDirectoriesLock = NSLock()
    private static var _darwinCacheDirectories: [AbsolutePath]? = .none

    /// Attempt to match `uname` with recognized platforms.
    internal static func findCurrentPlatform(_ fileSystem: FileSystem) -> Platform? {
        #if os(Windows)
        return .windows
        #else
        guard let uname = try? Process.checkNonZeroExit(args: "uname").spm_chomp().lowercased() else { return nil }
        switch uname {
        case "darwin":
            return .darwin
        case "linux":
            return Platform.findCurrentPlatformLinux(fileSystem)
        default:
            return nil
        }
        #endif
    }

    internal static func findCurrentPlatformLinux(_ fileSystem: FileSystem) -> Platform? {
        do {
            if try fileSystem.isFile(AbsolutePath(validating: "/etc/debian_version")) {
                return .linux(.debian)
            }
            if try fileSystem.isFile(AbsolutePath(validating: "/system/bin/toolbox")) ||
                fileSystem.isFile(AbsolutePath(validating: "/system/bin/toybox")) {
                return .android
            }
            if try fileSystem.isFile(AbsolutePath(validating: "/etc/redhat-release")) ||
                fileSystem.isFile(AbsolutePath(validating: "/etc/centos-release")) ||
                fileSystem.isFile(AbsolutePath(validating: "/etc/fedora-release")) ||
                Platform.isAmazonLinux2(fileSystem) {
                return .linux(.fedora)
            }
        } catch {}

        return nil
    }

    private static func isAmazonLinux2(_ fileSystem: FileSystem) -> Bool {
        do {
            let release = try fileSystem.readFileContents(AbsolutePath(validating: "/etc/system-release")).cString
            return release.hasPrefix("Amazon Linux release 2")
        } catch {
            return false
        }
    }

    /// Returns the cache directories used in Darwin.
    public static func darwinCacheDirectories() throws -> [AbsolutePath] {
        try Self.darwinCacheDirectoriesLock.withLock {
            if let darwinCacheDirectories = Self._darwinCacheDirectories {
                return darwinCacheDirectories
            }
            var directories = [AbsolutePath]()
            // Compute the directories.
            try directories.append(AbsolutePath(validating: "/private/var/tmp"))
            (try? TSCBasic.determineTempDirectory()).map{ directories.append($0) }
            #if canImport(Darwin)
            getConfstr(_CS_DARWIN_USER_TEMP_DIR).map({ directories.append($0) })
            getConfstr(_CS_DARWIN_USER_CACHE_DIR).map({ directories.append($0) })
            #endif
            Self._darwinCacheDirectories = directories
            return directories
        }
    }


    #if canImport(Darwin)
    /// Returns the value of given path variable using `getconf` utility.
    ///
    /// - Note: This method returns `nil` if the value is an invalid path.
    private static func getConfstr(_ name: Int32) -> AbsolutePath? {
        let len = confstr(name, nil, 0)
        let tmp = UnsafeMutableBufferPointer(start: UnsafeMutablePointer<Int8>.allocate(capacity: len), count:len)
        defer { tmp.deallocate() }
        guard confstr(name, tmp.baseAddress, len) == len else { return nil }
        let value = String(cString: tmp.baseAddress!)
        guard value.hasSuffix(AbsolutePath.root.pathString) else { return nil }
        return try? resolveSymlinks(AbsolutePath(validating: value))
    }
    #endif
}
