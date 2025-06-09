/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import TSCLibc
import class Foundation.FileHandle
import class Foundation.FileManager
import func Foundation.NSTemporaryDirectory
import protocol Foundation.CustomNSError
import var Foundation.NSLocalizedDescriptionKey

public enum TempFileError: Error {
    /// Could not create a unique temporary filename.
    case couldNotCreateUniqueName

    // FIXME: This should be factored out into a open error enum.
    //
    /// Some error thrown defined by posix's open().
    case other(Int32)

    /// Couldn't find a temporary directory.
    case couldNotFindTmpDir(String)
}

extension TempFileError: CustomNSError {
    public var errorUserInfo: [String : Any] {
        return [NSLocalizedDescriptionKey: "\(self)"]
    }
}

private extension TempFileError {
    init(errno: Int32) {
        switch errno {
        case TSCLibc.EEXIST:
            self = .couldNotCreateUniqueName
        default:
            self = .other(errno)
        }
    }
}

/// Determines the directory in which the temporary file should be created. Also makes
/// sure the returning path has a trailing forward slash.
///
/// - Parameters:
///     - dir: If present this will be the temporary directory.
///
/// - Returns: Path to directory in which temporary file should be created.
public func determineTempDirectory(_ dir: AbsolutePath? = nil) throws -> AbsolutePath {
    let tmpDir = try dir ?? localFileSystem.tempDirectory
    guard localFileSystem.isDirectory(tmpDir) else {
        throw TempFileError.couldNotFindTmpDir(tmpDir.pathString)
    }
    return tmpDir
}

/// The closure argument of the `body` closure of `withTemporaryFile`.
public struct TemporaryFile {
    /// If specified during init, the temporary file name begins with this prefix.
    let prefix: String

    /// If specified during init, the temporary file name ends with this suffix.
    let suffix: String

    /// The directory in which the temporary file is created.
    public let dir: AbsolutePath

    /// The full path of the temporary file. For safety file operations should be done via the fileHandle instead of
    /// using this path.
    public let path: AbsolutePath

    /// The file descriptor of the temporary file. It is used to create NSFileHandle which is exposed to clients.
    private let fd: Int32

    /// FileHandle of the temporary file, can be used to read/write data.
    public let fileHandle: FileHandle

    fileprivate init(dir: AbsolutePath?, prefix: String, suffix: String) throws {
        self.suffix = suffix
        self.prefix = prefix
        // Determine in which directory to create the temporary file.
        self.dir = try determineTempDirectory(dir)
        // Construct path to the temporary file.
        let path = try AbsolutePath(validating: prefix + ".XXXXXX" + suffix, relativeTo: self.dir)

        // Convert path to a C style string terminating with null char to be an valid input
        // to mkstemps method. The XXXXXX in this string will be replaced by a random string
        // which will be the actual path to the temporary file.
        var template = Array(path.pathString.utf8CString)

        fd = TSCLibc.mkstemps(&template, Int32(suffix.utf8.count))
        // If mkstemps failed then throw error.
        if fd == -1 { throw TempFileError(errno: errno) }

        self.path = try AbsolutePath(validating: String(cString: template))
        fileHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }
}

extension TemporaryFile: CustomStringConvertible {
    public var description: String {
        return "<TemporaryFile: \(path)>"
    }
}

/// Creates a temporary file and evaluates a closure with the temporary file as an argument.
/// The temporary file will live on disk while the closure is evaluated and will be deleted when
/// the cleanup block is called.
///
/// This function is basically a wrapper over posix's mkstemps() function to create disposable files.
///
/// - Parameters:
///     - dir: If specified the temporary file will be created in this directory otherwise environment variables
///            TMPDIR, TEMP and TMP will be checked for a value (in that order). If none of the env variables are
///            set, dir will be set to `/tmp/`.
///     - prefix: The prefix to the temporary file name.
///     - suffix: The suffix to the temporary file name.
///     - body: A closure to execute that receives the TemporaryFile as an argument.
///             If `body` has a return value, that value is also used as the
///             return value for the `withTemporaryFile` function.
///             The cleanup block should be called when the temporary file is no longer needed.
///
/// - Throws: TempFileError and rethrows all errors from `body`.
public func withTemporaryFile<Result>(
  dir: AbsolutePath? = nil, prefix: String = "TemporaryFile", suffix: String = "", _ body: (TemporaryFile, @escaping (TemporaryFile) -> Void) throws -> Result
) throws -> Result {
    return try body(TemporaryFile(dir: dir, prefix: prefix, suffix: suffix)) { tempFile in
#if os(Windows)
        _ = tempFile.path.pathString.withCString(encodedAs: UTF16.self) {
          _wunlink($0)
        }
#else
        unlink(tempFile.path.pathString)
#endif
    }
}

/// Creates a temporary file and evaluates a closure with the temporary file as an argument.
/// The temporary file will live on disk while the closure is evaluated and will be deleted when
/// the cleanup block is called.
///
/// This function is basically a wrapper over posix's mkstemps() function to create disposable files.
///
/// - Parameters:
///     - dir: If specified the temporary file will be created in this directory otherwise environment variables
///            TMPDIR, TEMP and TMP will be checked for a value (in that order). If none of the env variables are
///            set, dir will be set to `/tmp/`.
///     - prefix: The prefix to the temporary file name.
///     - suffix: The suffix to the temporary file name.
///     - body: A closure to execute that receives the TemporaryFile as an argument.
///             If `body` has a return value, that value is also used as the
///             return value for the `withTemporaryFile` function.
///             The cleanup block should be called when the temporary file is no longer needed.
///
/// - Throws: TempFileError and rethrows all errors from `body`.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func withTemporaryFile<Result>(
    dir: AbsolutePath? = nil, prefix: String = "TemporaryFile", suffix: String = "", _ body: (TemporaryFile, @escaping (TemporaryFile) async -> Void) async throws -> Result
) async throws -> Result {
    return try await body(TemporaryFile(dir: dir, prefix: prefix, suffix: suffix)) { tempFile in
#if os(Windows)
        _ = tempFile.path.pathString.withCString(encodedAs: UTF16.self) {
            _wunlink($0)
        }
#else
        unlink(tempFile.path.pathString)
#endif
    }
}

/// Creates a temporary file and evaluates a closure with the temporary file as an argument.
/// The temporary file will live on disk while the closure is evaluated and will be deleted afterwards.
///
/// This function is basically a wrapper over posix's mkstemps() function to create disposable files.
///
/// - Parameters:
///     - dir: If specified the temporary file will be created in this directory otherwise environment variables
///            TMPDIR, TEMP and TMP will be checked for a value (in that order). If none of the env variables are
///            set, dir will be set to `/tmp/`.
///     - prefix: The prefix to the temporary file name.
///     - suffix: The suffix to the temporary file name.
///     - deleteOnClose: Whether the file should get deleted after the call of `body`
///     - body: A closure to execute that receives the TemporaryFile as an argument.
///            If `body` has a return value, that value is also used as the
///            return value for the `withTemporaryFile` function.
///
/// - Throws: TempFileError and rethrows all errors from `body`.
public func withTemporaryFile<Result>(
  dir: AbsolutePath? = nil, prefix: String = "TemporaryFile", suffix: String = "", deleteOnClose: Bool = true, _ body: (TemporaryFile) throws -> Result
) throws -> Result {
    try withTemporaryFile(dir: dir, prefix: prefix, suffix: suffix) { tempFile, cleanup in
        defer { if (deleteOnClose) { cleanup(tempFile) } }
        return try body(tempFile)
    }
}

/// Creates a temporary file and evaluates a closure with the temporary file as an argument.
/// The temporary file will live on disk while the closure is evaluated and will be deleted afterwards.
///
/// This function is basically a wrapper over posix's mkstemps() function to create disposable files.
///
/// - Parameters:
///     - dir: If specified the temporary file will be created in this directory otherwise environment variables
///            TMPDIR, TEMP and TMP will be checked for a value (in that order). If none of the env variables are
///            set, dir will be set to `/tmp/`.
///     - prefix: The prefix to the temporary file name.
///     - suffix: The suffix to the temporary file name.
///     - deleteOnClose: Whether the file should get deleted after the call of `body`
///     - body: A closure to execute that receives the TemporaryFile as an argument.
///            If `body` has a return value, that value is also used as the
///            return value for the `withTemporaryFile` function.
///
/// - Throws: TempFileError and rethrows all errors from `body`.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func withTemporaryFile<Result>(
    dir: AbsolutePath? = nil, prefix: String = "TemporaryFile", suffix: String = "", deleteOnClose: Bool = true, _ body: (TemporaryFile) async throws -> Result
) async throws -> Result {
    try await withTemporaryFile(dir: dir, prefix: prefix, suffix: suffix) { tempFile, cleanup in
        let result: Result
        do {
            result = try await body(tempFile)
            if (deleteOnClose) { await cleanup(tempFile) }
        } catch {
            if (deleteOnClose) { await cleanup(tempFile) }
            throw error
        }
        return result
    }
}

// FIXME: This isn't right place to declare this, probably POSIX or merge with FileSystemError?
//
/// Contains the error which can be thrown while creating a directory using POSIX's mkdir.
public enum MakeDirectoryError: Error {
    /// The given path already exists as a directory, file or symbolic link.
    case pathExists
    /// The path provided was too long.
    case pathTooLong
    /// Process does not have permissions to create directory.
    /// Note: Includes read-only filesystems or if file system does not support directory creation.
    case permissionDenied
    /// The path provided is unresolvable because it has too many symbolic links or a path component is invalid.
    case unresolvablePathComponent
    /// Exceeded user quota or kernel is out of memory.
    case outOfMemory
    /// All other system errors with their value.
    case other(Int32)
}

private extension MakeDirectoryError {
    init(errno: Int32) {
        switch errno {
        case TSCLibc.EEXIST:
            self = .pathExists
        case TSCLibc.ENAMETOOLONG:
            self = .pathTooLong
        case TSCLibc.EACCES, TSCLibc.EFAULT, TSCLibc.EPERM, TSCLibc.EROFS:
            self = .permissionDenied
        case TSCLibc.ELOOP, TSCLibc.ENOENT, TSCLibc.ENOTDIR:
            self = .unresolvablePathComponent
        case TSCLibc.ENOMEM:
            self = .outOfMemory
#if !os(Windows)
        case TSCLibc.EDQUOT:
            self = .outOfMemory
#endif
        default:
            self = .other(errno)
        }
    }
}

extension MakeDirectoryError: CustomNSError {
    public var errorUserInfo: [String : Any] {
        return [NSLocalizedDescriptionKey: "\(self)"]
    }
}

/// Creates a temporary directory and evaluates a closure with the directory path as an argument.
/// The temporary directory will live on disk while the closure is evaluated and will be deleted when
/// the cleanup closure is called. This allows the temporary directory to have an arbitrary lifetime.
///
/// This function is basically a wrapper over posix's mkdtemp() function.
///
/// - Parameters:
///     - dir: If specified the temporary directory will be created in this directory otherwise environment
///            variables TMPDIR, TEMP and TMP will be checked for a value (in that order). If none of the env
///            variables are set, dir will be set to `/tmp/`.
///     - prefix: The prefix to the temporary file name.
///     - body: A closure to execute that receives the absolute path of the directory as an argument.
///           If `body` has a return value, that value is also used as the
///           return value for the `withTemporaryDirectory` function.
///           The cleanup block should be called when the temporary directory is no longer needed.
///
/// - Throws: MakeDirectoryError and rethrows all errors from `body`.
public func withTemporaryDirectory<Result>(
    dir: AbsolutePath? = nil, prefix: String = "TemporaryDirectory" , _ body: (AbsolutePath, @escaping (AbsolutePath) -> Void) throws -> Result
) throws -> Result {
    // Construct path to the temporary directory.
    let templatePath = try AbsolutePath(validating: prefix + ".XXXXXX", relativeTo: determineTempDirectory(dir))

    // Convert templatePath to a C style string terminating with null char to be an valid input
    // to mkdtemp method. The XXXXXX in this string will be replaced by a random string
    // which will be the actual path to the temporary directory.
    var template = [UInt8](templatePath.pathString.utf8).map({ Int8($0) }) + [Int8(0)]

    if TSCLibc.mkdtemp(&template) == nil {
        throw MakeDirectoryError(errno: errno)
    }

    return try body(AbsolutePath(validating: String(cString: template))) { path in
        _ = try? FileManager.default.removeItem(atPath: path.pathString)
    }
}

/// Creates a temporary directory and evaluates a closure with the directory path as an argument.
/// The temporary directory will live on disk while the closure is evaluated and will be deleted when
/// the cleanup closure is called. This allows the temporary directory to have an arbitrary lifetime.
///
/// This function is basically a wrapper over posix's mkdtemp() function.
///
/// - Parameters:
///     - dir: If specified the temporary directory will be created in this directory otherwise environment
///            variables TMPDIR, TEMP and TMP will be checked for a value (in that order). If none of the env
///            variables are set, dir will be set to `/tmp/`.
///     - prefix: The prefix to the temporary file name.
///     - body: A closure to execute that receives the absolute path of the directory as an argument.
///           If `body` has a return value, that value is also used as the
///           return value for the `withTemporaryDirectory` function.
///           The cleanup block should be called when the temporary directory is no longer needed.
///
/// - Throws: MakeDirectoryError and rethrows all errors from `body`.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func withTemporaryDirectory<Result>(
    dir: AbsolutePath? = nil, prefix: String = "TemporaryDirectory" , _ body: (AbsolutePath, @escaping (AbsolutePath) async -> Void) async throws -> Result
) async throws -> Result {
    // Construct path to the temporary directory.
    let templatePath = try AbsolutePath(validating: prefix + ".XXXXXX", relativeTo: determineTempDirectory(dir))

    // Convert templatePath to a C style string terminating with null char to be an valid input
    // to mkdtemp method. The XXXXXX in this string will be replaced by a random string
    // which will be the actual path to the temporary directory.
    var template = [UInt8](templatePath.pathString.utf8).map({ Int8($0) }) + [Int8(0)]

    if TSCLibc.mkdtemp(&template) == nil {
        throw MakeDirectoryError(errno: errno)
    }

    return try await body(AbsolutePath(validating: String(cString: template))) { path in
        _ = try? FileManager.default.removeItem(atPath: path.pathString)
    }
}

/// Creates a temporary directory and evaluates a closure with the directory path as an argument.
/// The temporary directory will live on disk while the closure is evaluated and will be deleted afterwards.
///
/// This function is basically a wrapper over posix's mkdtemp() function.
///
/// - Parameters:
///     - dir: If specified the temporary directory will be created in this directory otherwise environment
///            variables TMPDIR, TEMP and TMP will be checked for a value (in that order). If none of the env
///            variables are set, dir will be set to `/tmp/`.
///     - prefix: The prefix to the temporary file name.
///     - removeTreeOnDeinit: If enabled try to delete the whole directory tree otherwise remove only if its empty.
///     - body: A closure to execute that receives the absolute path of the directory as an argument.
///             If `body` has a return value, that value is also used as the
///             return value for the `withTemporaryDirectory` function.
///
/// - Throws: MakeDirectoryError and rethrows all errors from `body`.
public func withTemporaryDirectory<Result>(
    dir: AbsolutePath? = nil, prefix: String = "TemporaryDirectory", removeTreeOnDeinit: Bool = false , _ body: (AbsolutePath) throws -> Result
) throws -> Result {
    try withTemporaryDirectory(dir: dir, prefix: prefix) { path, cleanup in
        defer { if removeTreeOnDeinit { cleanup(path) } }
        return try body(path)
    }
}

/// Creates a temporary directory and evaluates a closure with the directory path as an argument.
/// The temporary directory will live on disk while the closure is evaluated and will be deleted afterwards.
///
/// This function is basically a wrapper over posix's mkdtemp() function.
///
/// - Parameters:
///     - dir: If specified the temporary directory will be created in this directory otherwise environment
///            variables TMPDIR, TEMP and TMP will be checked for a value (in that order). If none of the env
///            variables are set, dir will be set to `/tmp/`.
///     - prefix: The prefix to the temporary file name.
///     - removeTreeOnDeinit: If enabled try to delete the whole directory tree otherwise remove only if its empty.
///     - body: A closure to execute that receives the absolute path of the directory as an argument.
///             If `body` has a return value, that value is also used as the
///             return value for the `withTemporaryDirectory` function.
///
/// - Throws: MakeDirectoryError and rethrows all errors from `body`.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func withTemporaryDirectory<Result>(
    dir: AbsolutePath? = nil, prefix: String = "TemporaryDirectory", removeTreeOnDeinit: Bool = false , _ body: (AbsolutePath) async throws -> Result
) async throws -> Result {
    try await withTemporaryDirectory(dir: dir, prefix: prefix) { path, cleanup in
        let result: Result
        do {
            result = try await body(path)
            if removeTreeOnDeinit { await cleanup(path) }
        } catch {
            if removeTreeOnDeinit { await cleanup(path) }
            throw error
        }
        return result
    }
}
