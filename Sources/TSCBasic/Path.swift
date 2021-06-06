/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/
import SystemPackage

import protocol Foundation.CustomNSError
import var Foundation.NSLocalizedDescriptionKey

public protocol Path: Hashable, Codable, CustomStringConvertible {
    /// Underlying type, based on SwiftSystem.
    var filepath: FilePath { get }

    /// Public initializer from FilePath.
    init(_ filepath: FilePath)

    /// Public initializer from String.
    init(_ string: String)

    /// Convenience initializer that verifies that the path lexically.
    init(validating path: String) throws

    /// Normalized string representation (the normalization rules are described
    /// in the documentation of the initializer).  This string is never empty.
    var pathString: String { get }

    /// The root of a path.
    var root: String? { get }

    /// Directory component.  An absolute path always has a non-empty directory
    /// component (the directory component of the root path is the root itself).
    var dirname: String { get }

    /// Last path component (including the suffix, if any).
    var basename: String { get }

    /// Returns the basename without the extension.
    var basenameWithoutExt: String { get }

    /// Extension of the give path's basename. This follow same rules as
    /// suffix except that it doesn't include leading `.` character.
    var `extension`: String? { get }

    /// Suffix (including leading `.` character) if any.  Note that a basename
    /// that starts with a `.` character is not considered a suffix, nor is a
    /// trailing `.` character.
    var suffix: String? { get }

    /// True if the path is a root directory.
    var isRoot: Bool { get }

    /// Returns the path with an additional literal component appended.
    ///
    /// This method accepts pseudo-path like '.' or '..', but should not contain "/".
    func appending(component: String) -> Self

    /// Returns the relative path with additional literal components appended.
    ///
    /// This method should only be used in cases where the input is guaranteed
    /// to be a valid path component (i.e., it cannot be empty, contain a path
    /// separator, or be a pseudo-path like '.' or '..').
    func appending(components names: [String]) -> Self
    func appending(components names: String...) -> Self

    /// Returns an array of strings that make up the path components of the
    /// path.  This is the same sequence of strings as the basenames of each
    /// successive path component.  An empty path has a single path
    /// component: the `.` string.
    ///
    /// NOTE: Path components no longer include the root.  Use `root` instead.
    var components: [String] { get }
}

/// Default implementations of some protocol stubs.
extension Path {
    public var pathString: String {
        if filepath.string.isEmpty {
            return "."
        }
        return filepath.string
    }

    public var root: String? {
        return filepath.root?.string
    }

    public var dirname: String {
        let dirname = filepath.removingLastComponent().string
        if dirname.isEmpty {
            return "."
        }
        return dirname
    }

    public var basename: String {
        return filepath.lastComponent?.string ?? root ?? "."
    }

    public var basenameWithoutExt: String {
        return filepath.lastComponent?.stem ?? root ?? "."
    }

    public var `extension`: String? {
        guard let ext = filepath.extension,
              !ext.isEmpty else {
            return nil
        }
        return filepath.extension
    }

    public var suffix: String? {
        if let ext = self.extension {
            return "." + ext
        } else {
            return nil
        }
    }

    public var isRoot: Bool {
        return filepath.isRoot
    }

    public func appending(component: String) -> Self {
        return Self(filepath.appending(
                                FilePath.Component(stringLiteral: component)))
    }

    public func appending(components names: [String]) -> Self {
        let components = names.map(FilePath.Component.init)
        return Self(filepath.appending(components))
    }

    public func appending(components names: String...) -> Self {
        appending(components: names)
    }

    public var components: [String] {
        var components = filepath.components.map(\.string)
        if filepath.isRelative && components.isEmpty {
            components.append(".")
        }
        return components
    }
}

/// Default implementation of `CustomStringConvertible`.
extension Path {
    public var description: String {
        return pathString
    }

    public var debugDescription: String {
        // FIXME: We should really be escaping backslashes and quotes here.
        return "<\(Self.self):\"\(pathString)\">"
    }
}

/// Default implementation of `Codable`.
extension Path {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(pathString)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(validating: container.decode(String.self))
    }
}

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
public struct AbsolutePath: Path {
    /// Underlying type, based on SwiftSystem.
    public let filepath: FilePath

    /// Public initializer with FilePath.
    public init(_ filepath: FilePath) {
        precondition(filepath.isAbsolute)
        self.filepath = filepath.lexicallyNormalized()
    }

    /// Initializes the AbsolutePath from `absStr`, which must be an absolute
    /// path (i.e. it must begin with a path separator; this initializer does
    /// not interpret leading `~` characters as home directory specifiers).
    /// The input string will be normalized if needed, as described in the
    /// documentation for AbsolutePath.
    public init(_ absStr: String) {
        self.init(FilePath(absStr))
    }

    /// Initializes an AbsolutePath from a string that may be either absolute
    /// or relative; if relative, `basePath` is used as the anchor; if absolute,
    /// it is used as is, and in this case `basePath` is ignored.
    public init(_ str: String, relativeTo basePath: AbsolutePath) {
        self.init(basePath.filepath.pushing(FilePath(str)))
    }

    /// Initializes the AbsolutePath by concatenating a relative path to an
    /// existing absolute path, and renormalizing if necessary.
    public init(_ absPath: AbsolutePath, _ relPath: RelativePath) {
        self.init(absPath.filepath.pushing(relPath.filepath))
    }

    /// Convenience initializer that appends a string to a relative path.
    public init(_ absPath: AbsolutePath, _ relStr: String) {
        self.init(absPath.filepath.pushing(FilePath(relStr)))
    }

    /// Convenience initializer that verifies that the path is absolute.
    public init(validating path: String) throws {
        try self.init(FilePath(validatingAbsolutePath: path))
    }

    /// Absolute path of parent directory.  This always returns a path, because
    /// every directory has a parent (the parent directory of the root directory
    /// is considered to be the root directory itself).
    public var parentDirectory: AbsolutePath {
        return AbsolutePath(filepath.removingLastComponent())
    }

    /// Returns the absolute path with the relative path applied.
    public func appending(_ subpath: RelativePath) -> AbsolutePath {
        return AbsolutePath(self, subpath)
    }

    /// NOTE: We will most likely want to add other `appending()` methods, such
    ///       as `appending(suffix:)`, and also perhaps `replacing()` methods,
    ///       such as `replacing(suffix:)` or `replacing(basename:)` for some
    ///       of the more common path operations.

    /// NOTE: We may want to consider adding operators such as `+` for appending
    ///       a path component.

    /// Returns the lowest common ancestor path.
    public func lowestCommonAncestor(with path: AbsolutePath) -> AbsolutePath? {
        guard root == path.root else {
            return nil
        }
        var filepath = path.filepath
        while (!filepath.isRoot) {
            if self.filepath.starts(with: filepath) {
                break
            }
            filepath.removeLastComponent()
        }
        return AbsolutePath(filepath)
    }

    /// The root directory. It is always `/` on UNIX, but may vary on Windows.
    @available(*, deprecated, message: "root is not a static value, use the instance property instead")
    public static var root: AbsolutePath {
        if let rootPath = localFileSystem.currentWorkingDirectory?.root {
            return AbsolutePath(rootPath)
        } else {
            return AbsolutePath(FilePath._root)
        }
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
public struct RelativePath: Path {
    /// Underlying type, based on SwiftSystem.
    public let filepath: FilePath

    /// Public initializer with FilePath.
    public init(_ filepath: FilePath) {
        precondition(filepath.isRelative)
        self.filepath = filepath.lexicallyNormalized()
    }

    /// Initializes the RelativePath from `str`, which must be a relative path
    /// (which means that it must not begin with a path separator or a tilde).
    /// An empty input path is allowed, but will be normalized to a single `.`
    /// character.  The input string will be normalized if needed, as described
    /// in the documentation for RelativePath.
    public init(_ string: String) {
        self.init(FilePath(string))
    }

    /// Convenience initializer that verifies that the path is relative.
    public init(validating path: String) throws {
        try self.init(FilePath(validatingRelativePath: path))
    }

    /// Returns the relative path with the given relative path applied.
    public func appending(_ subpath: RelativePath) -> RelativePath {
        return
            RelativePath(filepath.pushing(subpath.filepath))
    }
}

// Make absolute paths Comparable.
extension AbsolutePath: Comparable {
    public static func < (lhs: AbsolutePath, rhs: AbsolutePath) -> Bool {
        return lhs.pathString < rhs.pathString
    }
}

/// Describes the way in which a path is invalid.
public enum PathValidationError: Error {
    case invalidAbsolutePath(String)
    case invalidRelativePath(String)
    case differentRoot(String, String)
}

extension PathValidationError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidAbsolutePath(let path):
            return "invalid absolute path '\(path)'"
        case .invalidRelativePath(let path):
            return "invalid relative path '\(path)'"
        case .differentRoot(let pathA, let pathB):
            return "absolute paths '\(pathA)' and '\(pathB)' have different roots"
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
    public func relative(to base: AbsolutePath) throws -> RelativePath {
        var relFilePath = FilePath()
        var filepath = filepath
#if os(Windows)
        /// TODO: DOS relative path may change the root.
        if root != base.root {
            throw PathValidationError.differentRoot(pathString, base.pathString)
        }
#endif
        filepath.root = base.filepath.root

        let commonAncestor = AbsolutePath(filepath).lowestCommonAncestor(with: base)!
        let walkbackDepth: Int = {
            var baseFilepath = base.filepath
            precondition(baseFilepath.removePrefix(commonAncestor.filepath))
            return baseFilepath.components.count
        }()
        precondition(filepath.removePrefix(commonAncestor.filepath))
        
        relFilePath.append(Array(repeating: FilePath.Component(".."), count: walkbackDepth))
        relFilePath.push(filepath)
        
        return RelativePath(relFilePath)
    }

    /// Returns true if the path contains the given path.
    ///
    /// This method is strictly syntactic and does not access the file system
    /// in any way.
    public func contains(_ other: AbsolutePath) -> Bool {
        return filepath.starts(with: other.filepath)
    }

}

extension PathValidationError: CustomNSError {
    public var errorUserInfo: [String : Any] {
        return [NSLocalizedDescriptionKey: self.description]
    }
}

extension FilePath {
    static var _root: FilePath {
#if os(Windows)
        return FilePath("\\")
#else
        return FilePath("/")
#endif
    }

    init(validatingAbsolutePath path: String) throws {
        self.init(path)
        guard self.isAbsolute else {
            throw PathValidationError.invalidAbsolutePath(path)
        }
    }

    init(validatingRelativePath path: String) throws {
        self.init(path)
        guard self.isRelative else {
            throw PathValidationError.invalidRelativePath(path)
        }
#if !os(Windows)
        guard self.components.first?.string != "~" else {
            throw PathValidationError.invalidRelativePath(path)
        }
#endif
    }

    var isRoot: Bool {
        root != nil && components.isEmpty
    }
}
