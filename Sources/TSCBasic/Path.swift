/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/
#if os(Windows)
import Foundation
import WinSDK
#endif

#if os(Windows)
private typealias PathImpl = WindowsPath
#else
private typealias PathImpl = UNIXPath
#endif

import protocol Foundation.CustomNSError
import var Foundation.NSLocalizedDescriptionKey

/// Represents an absolute file system path, independently of what (or whether
/// anything at all) exists at that path in the file system at any given time.
/// An absolute path always starts with a `/` character, and holds a normalized
/// string representation.  This normalization is strictly syntactic, and does
/// not access the file system in any way.
///
/// The absolute path string is normalized by:
/// - Collapsing `..` path components
/// - Removing `.` path components
/// - Removing any trailing path separator
/// - Removing any redundant path separators
///
/// This string manipulation may change the meaning of a path if any of the
/// path components are symbolic links on disk.  However, the file system is
/// never accessed in any way when initializing an AbsolutePath.
///
/// Note that `~` (home directory resolution) is *not* done as part of path
/// normalization, because it is normally the responsibility of the shell and
/// not the program being invoked (e.g. when invoking `cd ~`, it is the shell
/// that evaluates the tilde; the `cd` command receives an absolute path).
public struct AbsolutePath: Hashable, Sendable {
    /// Check if the given name is a valid individual path component.
    ///
    /// This only checks with regard to the semantics enforced by `AbsolutePath`
    /// and `RelativePath`; particular file systems may have their own
    /// additional requirements.
    static func isValidComponent(_ name: String) -> Bool {
        return PathImpl.isValidComponent(name)
    }

    /// Private implementation details, shared with the RelativePath struct.
    private let _impl: PathImpl

    /// Private initializer when the backing storage is known.
    private init(_ impl: PathImpl) {
        _impl = impl
    }

    /// Initializes an AbsolutePath from a string that may be either absolute
    /// or relative; if relative, `basePath` is used as the anchor; if absolute,
    /// it is used as is, and in this case `basePath` is ignored.
    public init(validating str: String, relativeTo basePath: AbsolutePath) throws {
        if PathImpl(string: str).isAbsolute {
            try self.init(validating: str)
        } else {
#if os(Windows)
            assert(!basePath.pathString.isEmpty)
            guard !str.isEmpty else {
                self.init(basePath._impl)
                return
            }

            let base: UnsafePointer<Int8> =
                basePath.pathString.fileSystemRepresentation
            defer { base.deallocate() }

            let path: UnsafePointer<Int8> = str.fileSystemRepresentation
            defer { path.deallocate() }

            var pwszResult: PWSTR!
            _ = String(cString: base).withCString(encodedAs: UTF16.self) { pwszBase in
                String(cString: path).withCString(encodedAs: UTF16.self) { pwszPath in
                    PathAllocCombine(pwszBase, pwszPath, ULONG(PATHCCH_ALLOW_LONG_PATHS.rawValue), &pwszResult)
                }
            }
            defer { LocalFree(pwszResult) }

            self.init(String(decodingCString: pwszResult, as: UTF16.self))
#else
            try self.init(basePath, RelativePath(validating: str))
#endif
        }
    }

    /// Initializes the AbsolutePath by concatenating a relative path to an
    /// existing absolute path, and renormalizing if necessary.
    public init(_ absPath: AbsolutePath, _ relPath: RelativePath) {
        self.init(absPath._impl.appending(relativePath: relPath._impl))
    }

    /// Convenience initializer that appends a string to a relative path.
    public init(_ absPath: AbsolutePath, validating relStr: String) throws {
        try self.init(absPath, RelativePath(validating: relStr))
    }

    /// Initializes the AbsolutePath from `absStr`, which must be an absolute
    /// path (i.e. it must begin with a path separator; this initializer does
    /// not interpret leading `~` characters as home directory specifiers).
    /// The input string will be normalized if needed, as described in the
    /// documentation for AbsolutePath.
    public init(validating path: String) throws {
        try self.init(PathImpl(validatingAbsolutePath: path))
    }

    /// Directory component.  An absolute path always has a non-empty directory
    /// component (the directory component of the root path is the root itself).
    public var dirname: String {
        return _impl.dirname
    }

    /// Last path component (including the suffix, if any).  it is never empty.
    public var basename: String {
        return _impl.basename
    }

    /// Returns the basename without the extension.
    public var basenameWithoutExt: String {
        if let ext = self.extension {
            return String(basename.dropLast(ext.count + 1))
        }
        return basename
    }

    /// Suffix (including leading `.` character) if any.  Note that a basename
    /// that starts with a `.` character is not considered a suffix, nor is a
    /// trailing `.` character.
    public var suffix: String? {
        return _impl.suffix
    }

    /// Extension of the give path's basename. This follow same rules as
    /// suffix except that it doesn't include leading `.` character.
    public var `extension`: String? {
        return _impl.extension
    }

    /// Absolute path of parent directory.  This always returns a path, because
    /// every directory has a parent (the parent directory of the root directory
    /// is considered to be the root directory itself).
    public var parentDirectory: AbsolutePath {
        return AbsolutePath(_impl.parentDirectory)
    }

    /// True if the path is the root directory.
    public var isRoot: Bool {
        return _impl.isRoot
    }

    /// Returns the absolute path with the relative path applied.
    public func appending(_ subpath: RelativePath) -> AbsolutePath {
        return AbsolutePath(self, subpath)
    }

    /// Returns the absolute path with an additional literal component appended.
    ///
    /// This method accepts pseudo-path like '.' or '..', but should not contain "/".
    public func appending(component: String) -> AbsolutePath {
        return AbsolutePath(_impl.appending(component: component))
    }

    /// Returns the absolute path with additional literal components appended.
    ///
    /// This method should only be used in cases where the input is guaranteed
    /// to be a valid path component (i.e., it cannot be empty, contain a path
    /// separator, or be a pseudo-path like '.' or '..').
    public func appending(components names: [String]) -> AbsolutePath {
        // FIXME: This doesn't seem a particularly efficient way to do this.
        return names.reduce(self, { path, name in
            path.appending(component: name)
        })
    }

    public func appending(components names: String...) -> AbsolutePath {
        appending(components: names)
    }

    /// NOTE: We will most likely want to add other `appending()` methods, such
    ///       as `appending(suffix:)`, and also perhaps `replacing()` methods,
    ///       such as `replacing(suffix:)` or `replacing(basename:)` for some
    ///       of the more common path operations.

    /// NOTE: We may want to consider adding operators such as `+` for appending
    ///       a path component.

    /// NOTE: We will want to add a method to return the lowest common ancestor
    ///       path.

    /// Root directory (whose string representation is just a path separator).
    public static let root = AbsolutePath(PathImpl.root)

    /// Normalized string representation (the normalization rules are described
    /// in the documentation of the initializer).  This string is never empty.
    public var pathString: String {
        return _impl.string
    }

    /// Returns an array of strings that make up the path components of the
    /// absolute path.  This is the same sequence of strings as the basenames
    /// of each successive path component, starting from the root.  Therefore
    /// the first path component of an absolute path is always `/`.
    public var components: [String] {
        return _impl.components
    }
}

/// Represents a relative file system path.  A relative path never starts with
/// a `/` character, and holds a normalized string representation.  As with
/// AbsolutePath, the normalization is strictly syntactic, and does not access
/// the file system in any way.
///
/// The relative path string is normalized by:
/// - Collapsing `..` path components that aren't at the beginning
/// - Removing extraneous `.` path components
/// - Removing any trailing path separator
/// - Removing any redundant path separators
/// - Replacing a completely empty path with a `.`
///
/// This string manipulation may change the meaning of a path if any of the
/// path components are symbolic links on disk.  However, the file system is
/// never accessed in any way when initializing a RelativePath.
public struct RelativePath: Hashable, Sendable {
    /// Private implementation details, shared with the AbsolutePath struct.
    fileprivate let _impl: PathImpl

    /// Private initializer when the backing storage is known.
    private init(_ impl: PathImpl) {
        _impl = impl
    }

    /// Convenience initializer that verifies that the path is relative.
    public init(validating path: String) throws {
        try self.init(PathImpl(validatingRelativePath: path))
    }

    /// Directory component.  For a relative path without any path separators,
    /// this is the `.` string instead of the empty string.
    public var dirname: String {
        return _impl.dirname
    }

    /// Last path component (including the suffix, if any).  It is never empty.
    public var basename: String {
        return _impl.basename
    }

    /// Returns the basename without the extension.
    public var basenameWithoutExt: String {
        if let ext = self.extension {
            return String(basename.dropLast(ext.count + 1))
        }
        return basename
    }

    /// Suffix (including leading `.` character) if any.  Note that a basename
    /// that starts with a `.` character is not considered a suffix, nor is a
    /// trailing `.` character.
    public var suffix: String? {
        return _impl.suffix
    }

    /// Extension of the give path's basename. This follow same rules as
    /// suffix except that it doesn't include leading `.` character.
    public var `extension`: String? {
        return _impl.extension
    }

    /// Normalized string representation (the normalization rules are described
    /// in the documentation of the initializer).  This string is never empty.
    public var pathString: String {
        return _impl.string
    }

    /// Returns an array of strings that make up the path components of the
    /// relative path.  This is the same sequence of strings as the basenames
    /// of each successive path component.  Therefore the returned array of
    /// path components is never empty; even an empty path has a single path
    /// component: the `.` string.
    public var components: [String] {
        return _impl.components
    }

    /// Returns the relative path with the given relative path applied.
    public func appending(_ subpath: RelativePath) -> RelativePath {
        return RelativePath(_impl.appending(relativePath: subpath._impl))
    }

    /// Returns the relative path with an additional literal component appended.
    ///
    /// This method accepts pseudo-path like '.' or '..', but should not contain "/".
    public func appending(component: String) -> RelativePath {
        return RelativePath(_impl.appending(component: component))
    }

    /// Returns the relative path with additional literal components appended.
    ///
    /// This method should only be used in cases where the input is guaranteed
    /// to be a valid path component (i.e., it cannot be empty, contain a path
    /// separator, or be a pseudo-path like '.' or '..').
    public func appending(components names: [String]) -> RelativePath {
        // FIXME: This doesn't seem a particularly efficient way to do this.
        return names.reduce(self, { path, name in
            path.appending(component: name)
        })
    }

    public func appending(components names: String...) -> RelativePath {
        appending(components: names)
    }
}

extension AbsolutePath: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(pathString)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(validating: container.decode(String.self))
    }
}

extension RelativePath: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(pathString)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(validating: container.decode(String.self))
    }
}

// Make absolute paths Comparable.
extension AbsolutePath: Comparable {
    public static func < (lhs: AbsolutePath, rhs: AbsolutePath) -> Bool {
        return lhs.pathString < rhs.pathString
    }
}

/// Make absolute paths CustomStringConvertible and CustomDebugStringConvertible.
extension AbsolutePath: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return pathString
    }

    public var debugDescription: String {
        // FIXME: We should really be escaping backslashes and quotes here.
        return "<AbsolutePath:\"\(pathString)\">"
    }
}

/// Make relative paths CustomStringConvertible and CustomDebugStringConvertible.
extension RelativePath: CustomStringConvertible {
    public var description: String {
        return _impl.string
    }

    public var debugDescription: String {
        // FIXME: We should really be escaping backslashes and quotes here.
        return "<RelativePath:\"\(_impl.string)\">"
    }
}

/// Private implementation shared between AbsolutePath and RelativePath.
protocol Path: Hashable {

    /// Root directory.
    static var root: Self { get }

    /// Checks if a string is a valid component.
    static func isValidComponent(_ name: String) -> Bool

    /// Normalized string of the (absolute or relative) path. Never empty.
    var string: String { get }

    /// Returns whether the path is the root path.
    var isRoot: Bool { get }

    /// Returns whether the path is an absolute path.
    var isAbsolute: Bool { get }

    /// Returns the directory part of the stored path (relying on the fact that it has been normalized). Returns a
    /// string consisting of just `.` if there is no directory part (which is the case if and only if there is no path
    /// separator).
    var dirname: String { get }

    /// Returns the last past component.
    var basename: String { get }

    /// Returns the components of the path between each path separator.
    var components: [String] { get }

    /// Path of parent directory. This always returns a path, because every directory has a parent (the parent
    /// directory of the root directory is considered to be the root directory itself).
    var parentDirectory: Self { get }

    /// Creates a path from its normalized string representation.
    init(string: String)

    /// Creates a path from a string representation, validates that it is a valid absolute path and normalizes it.
    init(validatingAbsolutePath: String) throws

    /// Creates a path from a string representation, validates that it is a valid relative path and normalizes it.
    init(validatingRelativePath: String) throws

    /// Returns suffix with leading `.` if withDot is true otherwise without it.
    func suffix(withDot: Bool) -> String?

    /// Returns a new Path by appending the path component.
    func appending(component: String) -> Self

    /// Returns a path by concatenating a relative path and renormalizing if necessary.
    func appending(relativePath: Self) -> Self
}

extension Path {
    var suffix: String? {
        return suffix(withDot: true)
    }

    var `extension`: String? {
        return suffix(withDot: false)
    }
}

#if os(Windows)
private struct WindowsPath: Path, Sendable {
    let string: String

    // NOTE: this is *NOT* a root path.  It is a drive-relative path that needs
    // to be specified due to assumptions in the APIs.  Use the platform
    // specific path separator as we should be normalizing the path normally.
    // This is required to make the `InMemoryFileSystem` correctly iterate
    // paths.
    static let root = Self(string: "\\")

    static func isValidComponent(_ name: String) -> Bool {
        return name != "" && name != "." && name != ".." && !name.contains("/")
    }

    static func isAbsolutePath(_ path: String) -> Bool {
        return !path.withCString(encodedAs: UTF16.self, PathIsRelativeW)
    }

    var dirname: String {
        let fsr: UnsafePointer<Int8> = self.string.fileSystemRepresentation
        defer { fsr.deallocate() }

        var path: String = String(cString: fsr)
        // PathCchRemoveFileSpec removes trailing '\' for a
        // path like 'c:\root\path\', which doesn't give us the parent
        // directory name. Thus, drop the trailing '\' before calling
        // PathCchRemoveFileSpec.
        var substring = path[path.startIndex..<path.endIndex]
        while !substring.isEmpty && substring.utf8.last == UInt8(ascii: "\\") {
            substring = substring.dropLast()
        }
        if !substring.isEmpty && substring.last != ":" {
            // Drop the trailing '\', unless the string path only
            // has '\', and unless the slashes are right after the drive letter.
            path = String(substring)
        }

        return path.withCString(encodedAs: UTF16.self) {
            let data = UnsafeMutablePointer(mutating: $0)
            PathCchRemoveFileSpec(data, path.count)
            return String(decodingCString: data, as: UTF16.self)
        }
    }

    var isAbsolute: Bool {
        return Self.isAbsolutePath(self.string)
    }

    public var isRoot: Bool {
        return self.string.withCString(encodedAs: UTF16.self, PathCchIsRoot)
    }

    var basename: String {
        let path: String = self.string
        return path.withCString(encodedAs: UTF16.self) {
            PathStripPathW(UnsafeMutablePointer(mutating: $0))
            return String(decodingCString: $0, as: UTF16.self)
        }
    }

    // FIXME: We should investigate if it would be more efficient to instead
    // return a path component iterator that does all its work lazily, moving
    // from one path separator to the next on-demand.
    //
    var components: [String] {
        let normalized: UnsafePointer<Int8> = string.fileSystemRepresentation
        defer { normalized.deallocate() }

        return String(cString: normalized).components(separatedBy: "\\").filter { !$0.isEmpty }
    }

    var parentDirectory: Self {
        return self == .root ? self : Self(string: dirname)
    }

    init(string: String) {
        if string.first?.isASCII ?? false, string.first?.isLetter ?? false, string.first?.isLowercase ?? false,
           string.count > 1, string[string.index(string.startIndex, offsetBy: 1)] == ":"
        {
            self.string = "\(string.first!.uppercased())\(string.dropFirst(1))"
        } else {
            self.string = string
        }
    }

    private static func repr(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
        let representation: UnsafePointer<Int8> = path.fileSystemRepresentation
        defer { representation.deallocate() }
        return String(cString: representation)
    }

    init(validatingAbsolutePath path: String) throws {
        let realpath = Self.repr(path)
        if !Self.isAbsolutePath(realpath) {
            throw PathValidationError.invalidAbsolutePath(path)
        }
        self.init(string: realpath)
    }

    init(validatingRelativePath path: String) throws {
        if path.isEmpty || path == "." {
            self.init(string: ".")
        } else {
            let realpath: String = Self.repr(path)
            // Treat a relative path as an invalid relative path...
            if Self.isAbsolutePath(realpath) || realpath.first == "\\" {
                throw PathValidationError.invalidRelativePath(path)
            }
            self.init(string: realpath)
        }
    }

    func suffix(withDot: Bool) -> String? {
        return self.string.withCString(encodedAs: UTF16.self) {
          if let pointer = PathFindExtensionW($0) {
            let substring = String(decodingCString: pointer, as: UTF16.self)
            guard substring.length > 0 else { return nil }
            return withDot ? substring : String(substring.dropFirst(1))
          }
          return nil
        }
    }

    func appending(component name: String) -> Self {
        var result: PWSTR?
        _ = string.withCString(encodedAs: UTF16.self) { root in
            name.withCString(encodedAs: UTF16.self) { path in
                PathAllocCombine(root, path, ULONG(PATHCCH_ALLOW_LONG_PATHS.rawValue), &result)
            }
        }
        defer { LocalFree(result) }
        return Self(string: String(decodingCString: result!, as: UTF16.self))
    }

    func appending(relativePath: Self) -> Self {
        var result: PWSTR?
        _ = string.withCString(encodedAs: UTF16.self) { root in
            relativePath.string.withCString(encodedAs: UTF16.self) { path in
                PathAllocCombine(root, path, ULONG(PATHCCH_ALLOW_LONG_PATHS.rawValue), &result)
            }
        }
        defer { LocalFree(result) }
        return Self(string: String(decodingCString: result!, as: UTF16.self))
    }
}
#else
private struct UNIXPath: Path, Sendable {
    let string: String

    static let root = Self(string: "/")

    static func isValidComponent(_ name: String) -> Bool {
        return name != "" && name != "." && name != ".." && !name.contains("/")
    }

    var dirname: String {
        // FIXME: This method seems too complicated; it should be simplified,
        //        if possible, and certainly optimized (using UTF8View).
        // Find the last path separator.
        guard let idx = string.lastIndex(of: "/") else {
            // No path separators, so the directory name is `.`.
            return "."
        }
        // Check if it's the only one in the string.
        if idx == string.startIndex {
            // Just one path separator, so the directory name is `/`.
            return "/"
        }
        // Otherwise, it's the string up to (but not including) the last path
        // separator.
        return String(string.prefix(upTo: idx))
    }

    var isAbsolute: Bool {
        return string.hasPrefix("/")
    }

    var isRoot: Bool {
        return self == Self.root
    }

    var basename: String {
        // FIXME: This method seems too complicated; it should be simplified,
        //        if possible, and certainly optimized (using UTF8View).
        // Check for a special case of the root directory.
        if string.spm_only == "/" {
            // Root directory, so the basename is a single path separator (the
            // root directory is special in this regard).
            return "/"
        }
        // Find the last path separator.
        guard let idx = string.lastIndex(of: "/") else {
            // No path separators, so the basename is the whole string.
            return string
        }
        // Otherwise, it's the string from (but not including) the last path
        // separator.
        return String(string.suffix(from: string.index(after: idx)))
    }

    // FIXME: We should investigate if it would be more efficient to instead
    // return a path component iterator that does all its work lazily, moving
    // from one path separator to the next on-demand.
    //
    var components: [String] {
        // FIXME: This isn't particularly efficient; needs optimization, and
        // in fact, it might well be best to return a custom iterator so we
        // don't have to allocate everything up-front.  It would be backed by
        // the path string and just return a slice at a time.
        let components = string.components(separatedBy: "/").filter({ !$0.isEmpty })

        if string.hasPrefix("/") {
            return ["/"] + components
        } else {
            return components
        }
    }

    var parentDirectory: Self {
        return self == .root ? self : Self(string: dirname)
    }

    init(string: String) {
        self.string = string
    }

    init(normalizingAbsolutePath path: String) {
        precondition(path.first == "/", "Failure normalizing \(path), absolute paths should start with '/'")

        // At this point we expect to have a path separator as first character.
        assert(path.first == "/")
        // Fast path.
        if !mayNeedNormalization(absolute: path) {
            self.init(string: path)
        }

        // Split the character array into parts, folding components as we go.
        // As we do so, we count the number of characters we'll end up with in
        // the normalized string representation.
        var parts: [String] = []
        var capacity = 0
        for part in path.split(separator: "/") {
            switch part.count {
              case 0:
                // Ignore empty path components.
                continue
              case 1 where part.first == ".":
                // Ignore `.` path components.
                continue
              case 2 where part.first == "." && part.last == ".":
                // If there's a previous part, drop it; otherwise, do nothing.
                if let prev = parts.last {
                    parts.removeLast()
                    capacity -= prev.count
                }
              default:
                // Any other component gets appended.
                parts.append(String(part))
                capacity += part.count
            }
        }
        capacity += max(parts.count, 1)

        // Create an output buffer using the capacity we've calculated.
        // FIXME: Determine the most efficient way to reassemble a string.
        var result = ""
        result.reserveCapacity(capacity)

        // Put the normalized parts back together again.
        var iter = parts.makeIterator()
        result.append("/")
        if let first = iter.next() {
            result.append(contentsOf: first)
            while let next = iter.next() {
                result.append("/")
                result.append(contentsOf: next)
            }
        }

        // Sanity-check the result (including the capacity we reserved).
        assert(!result.isEmpty, "unexpected empty string")
        assert(result.count == capacity, "count: " +
            "\(result.count), cap: \(capacity)")

        // Use the result as our stored string.
        self.init(string: result)
    }

    init(normalizingRelativePath path: String) {
        precondition(path.first != "/")

        // FIXME: Here we should also keep track of whether anything actually has
        // to be changed in the string, and if not, just return the existing one.

        // Split the character array into parts, folding components as we go.
        // As we do so, we count the number of characters we'll end up with in
        // the normalized string representation.
        var parts: [String] = []
        var capacity = 0
        for part in path.split(separator: "/") {
            switch part.count {
            case 0:
                // Ignore empty path components.
                continue
            case 1 where part.first == ".":
                // Ignore `.` path components.
                continue
            case 2 where part.first == "." && part.last == ".":
                // If at beginning, fall through to treat the `..` literally.
                guard let prev = parts.last else {
                    fallthrough
                }
                // If previous component is anything other than `..`, drop it.
                if !(prev.count == 2 && prev.first == "." && prev.last == ".") {
                    parts.removeLast()
                    capacity -= prev.count
                    continue
                }
                // Otherwise, fall through to treat the `..` literally.
                fallthrough
            default:
                // Any other component gets appended.
                parts.append(String(part))
                capacity += part.count
            }
        }
        capacity += max(parts.count - 1, 0)

        // Create an output buffer using the capacity we've calculated.
        // FIXME: Determine the most efficient way to reassemble a string.
        var result = ""
        result.reserveCapacity(capacity)

        // Put the normalized parts back together again.
        var iter = parts.makeIterator()
        if let first = iter.next() {
            result.append(contentsOf: first)
            while let next = iter.next() {
                result.append("/")
                result.append(contentsOf: next)
            }
        }

        // Sanity-check the result (including the capacity we reserved).
        assert(result.count == capacity, "count: " +
            "\(result.count), cap: \(capacity)")

        // If the result is empty, return `.`, otherwise we return it as a string.
        self.init(string: result.isEmpty ? "." : result)
    }

    init(validatingAbsolutePath path: String) throws {
        switch path.first {
        case "/":
            self.init(normalizingAbsolutePath: path)
        case "~":
            throw PathValidationError.startsWithTilde(path)
        default:
            throw PathValidationError.invalidAbsolutePath(path)
        }
    }

    init(validatingRelativePath path: String) throws {
        switch path.first {
        case "/":
            throw PathValidationError.invalidRelativePath(path)
        default:
            self.init(normalizingRelativePath: path)
        }
    }

    func suffix(withDot: Bool) -> String? {
        // FIXME: This method seems too complicated; it should be simplified,
        //        if possible, and certainly optimized (using UTF8View).
        // Find the last path separator, if any.
        let sIdx = string.lastIndex(of: "/")
        // Find the start of the basename.
        let bIdx = (sIdx != nil) ? string.index(after: sIdx!) : string.startIndex
        // Find the last `.` (if any), starting from the second character of
        // the basename (a leading `.` does not make the whole path component
        // a suffix).
        let fIdx = string.index(bIdx, offsetBy: 1, limitedBy: string.endIndex) ?? string.startIndex
        if let idx = string[fIdx...].lastIndex(of: ".") {
            // Unless it's just a `.` at the end, we have found a suffix.
            if string.distance(from: idx, to: string.endIndex) > 1 {
                let fromIndex = withDot ? idx : string.index(idx, offsetBy: 1)
                return String(string.suffix(from: fromIndex))
            } else {
                return nil
            }
        }
        // If we get this far, there is no suffix.
        return nil
    }

    func appending(component name: String) -> Self {
        assert(!name.contains("/"), "\(name) is invalid path component")

        // Handle pseudo paths.
        switch name {
        case "", ".":
            return self
        case "..":
            return self.parentDirectory
        default:
            break
        }

        if self == Self.root {
            return Self(string: "/" + name)
        } else {
            return Self(string: string + "/" + name)
        }
    }

    func appending(relativePath: Self) -> Self {
        // Both paths are already normalized.  The only case in which we have
        // to renormalize their concatenation is if the relative path starts
        // with a `..` path component.
        var newPathString = string
        if self != .root {
            newPathString.append("/")
        }

        let relativePathString = relativePath.string
        newPathString.append(relativePathString)

        // If the relative string starts with `.` or `..`, we need to normalize
        // the resulting string.
        // FIXME: We can actually optimize that case, since we know that the
        // normalization of a relative path can leave `..` path components at
        // the beginning of the path only.
        if relativePathString.hasPrefix(".") {
            if newPathString.hasPrefix("/") {
                return Self(normalizingAbsolutePath: newPathString)
            } else {
                return Self(normalizingRelativePath: newPathString)
            }
        } else {
            return Self(string: newPathString)
        }
    }
}
#endif

/// Describes the way in which a path is invalid.
public enum PathValidationError: Error {
    case startsWithTilde(String)
    case invalidAbsolutePath(String)
    case invalidRelativePath(String)
}

extension PathValidationError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .startsWithTilde(let path):
            return "invalid absolute path '\(path)'; absolute path must begin with '/'"
        case .invalidAbsolutePath(let path):
            return "invalid absolute path '\(path)'"
        case .invalidRelativePath(let path):
            return "invalid relative path '\(path)'; relative path should not begin with '\(AbsolutePath.root.pathString)'"
        }
    }
}

extension AbsolutePath {
    /// Returns a relative path that, when concatenated to `base`, yields the
    /// callee path itself.  If `base` is not an ancestor of the callee, the
    /// returned path will begin with one or more `..` path components.
    ///
    /// Because both paths are absolute, they always have a common ancestor
    /// (the root path, if nothing else).  Therefore, any path can be made
    /// relative to any other path by using a sufficient number of `..` path
    /// components.
    ///
    /// This method is strictly syntactic and does not access the file system
    /// in any way.  Therefore, it does not take symbolic links into account.
    public func relative(to base: AbsolutePath) -> RelativePath {
        let result: RelativePath
        // Split the two paths into their components.
        // FIXME: The is needs to be optimized to avoid unncessary copying.
        let pathComps = self.components
        let baseComps = base.components

        // It's common for the base to be an ancestor, so try that first.
        if pathComps.starts(with: baseComps) {
            // Special case, which is a plain path without `..` components.  It
            // might be an empty path (when self and the base are equal).
            let relComps = pathComps.dropFirst(baseComps.count)
#if os(Windows)
            let pathString = relComps.joined(separator: "\\")
#else
            let pathString = relComps.joined(separator: "/")
#endif
            do {
                result = try RelativePath(validating: pathString)
            } catch {
                preconditionFailure("invalid relative path computed from \(pathString)")
            }

        } else {
            // General case, in which we might well need `..` components to go
            // "up" before we can go "down" the directory tree.
            var newPathComps = ArraySlice(pathComps)
            var newBaseComps = ArraySlice(baseComps)
            while newPathComps.prefix(1) == newBaseComps.prefix(1) {
                // First component matches, so drop it.
                newPathComps = newPathComps.dropFirst()
                newBaseComps = newBaseComps.dropFirst()
            }
            // Now construct a path consisting of as many `..`s as are in the
            // `newBaseComps` followed by what remains in `newPathComps`.
            var relComps = Array(repeating: "..", count: newBaseComps.count)
            relComps.append(contentsOf: newPathComps)
#if os(Windows)
            let pathString = relComps.joined(separator: "\\")
#else
            let pathString = relComps.joined(separator: "/")
#endif
            do {
                result = try RelativePath(validating: pathString)
            } catch {
                preconditionFailure("invalid relative path computed from \(pathString)")
            }
        }

        assert(AbsolutePath(base, result) == self)
        return result
    }

    /// Returns true if the path contains the given path.
    ///
    /// This method is strictly syntactic and does not access the file system
    /// in any way.
    @available(*, deprecated, renamed: "isDescendantOfOrEqual(to:)")
    public func contains(_ other: AbsolutePath) -> Bool {
        return isDescendantOfOrEqual(to: other)
    }

    /// Returns true if the path is an ancestor of the given path.
    ///
    /// This method is strictly syntactic and does not access the file system
    /// in any way.
    public func isAncestor(of descendant: AbsolutePath) -> Bool {
        return descendant.components.dropLast().starts(with: self.components)
    }

    /// Returns true if the path is an ancestor of or equal to the given path.
    ///
    /// This method is strictly syntactic and does not access the file system
    /// in any way.
    public func isAncestorOfOrEqual(to descendant: AbsolutePath) -> Bool {
        return descendant.components.starts(with: self.components)
    }

    /// Returns true if the path is a descendant of the given path.
    ///
    /// This method is strictly syntactic and does not access the file system
    /// in any way.
    public func isDescendant(of ancestor: AbsolutePath) -> Bool {
        return self.components.dropLast().starts(with: ancestor.components)
    }

    /// Returns true if the path is a descendant of or equal to the given path.
    ///
    /// This method is strictly syntactic and does not access the file system
    /// in any way.
    public func isDescendantOfOrEqual(to ancestor: AbsolutePath) -> Bool {
        return self.components.starts(with: ancestor.components)
    }
}

extension PathValidationError: CustomNSError {
    public var errorUserInfo: [String : Any] {
        return [NSLocalizedDescriptionKey: self.description]
    }
}

// FIXME: We should consider whether to merge the two `normalize()` functions.
// The argument for doing so is that some of the code is repeated; the argument
// against doing so is that some of the details are different, and since any
// given path is either absolute or relative, it's wasteful to keep checking
// for whether it's relative or absolute.  Possibly we can do both by clever
// use of generics that abstract away the differences.

/// Fast check for if a string might need normalization.
///
/// This assumes that paths containing dotfiles are rare:
private func mayNeedNormalization(absolute string: String) -> Bool {
    var last = UInt8(ascii: "0")
    for c in string.utf8 {
        switch c {
        case UInt8(ascii: "/") where last == UInt8(ascii: "/"):
            return true
        case UInt8(ascii: ".") where last == UInt8(ascii: "/"):
            return true
        default:
            break
        }
        last = c
    }
    if last == UInt8(ascii: "/") {
        return true
    }
    return false
}

// MARK: - `AbsolutePath` backwards compatibility, delete after deprecation period.

extension AbsolutePath {
    @_disfavoredOverload
    @available(*, deprecated, message: "use throwing `init(validating:)` variant instead")
    public init(_ absStr: String) {
        try! self.init(validating: absStr)
    }

    @_disfavoredOverload
    @available(*, deprecated, message: "use throwing `init(validating:relativeTo:)` variant instead")
    public init(_ str: String, relativeTo basePath: AbsolutePath) {
        try! self.init(validating: str, relativeTo: basePath)
    }

    @_disfavoredOverload
    @available(*, deprecated, message: "use throwing variant instead")
    public init(_ absPath: AbsolutePath, _ relStr: String) {
        try! self.init(absPath, validating: relStr)
    }
}

// MARK: - `AbsolutePath` backwards compatibility, delete after deprecation period.

extension RelativePath {
    @_disfavoredOverload
    @available(*, deprecated, message: "use throwing variant instead")
    public init(_ string: String) {
        try! self.init(validating: string)
    }
}
