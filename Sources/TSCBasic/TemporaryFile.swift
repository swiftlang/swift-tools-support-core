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

public enum TempFileError: Swift.Error {
    /// Could not create a unique temporary filename.
    case couldNotCreateUniqueName

    // FIXME: This should be factored out into a open error enum.
    //
    /// Some error thrown defined by posix's open().
    case other(Int32)

    /// Couldn't find a temporary directory.
    case couldNotFindTmpDir
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
    let tmpDir = dir ?? cachedTempDirectory
    guard localFileSystem.isDirectory(tmpDir) else {
        throw TempFileError.couldNotFindTmpDir
    }
    return tmpDir
}

/// Returns temporary directory location by searching relevant env variables.
///
/// Evaluates once per execution.
private var cachedTempDirectory: AbsolutePath = {
    let override = ProcessEnv.vars["TMPDIR"] ?? ProcessEnv.vars["TEMP"] ?? ProcessEnv.vars["TMP"]
    if let path = override.flatMap({ try? AbsolutePath(validating: $0) }) {
        return path
    }
    return AbsolutePath(NSTemporaryDirectory())
}()

// NOTE: These two functions are lifted from Foundation.  They are not part of
// the public interface from Foundation, so we have replicated them here to
// provide a platform agnostic way to create temporary files and directories on
// platforms which do not provide `mkstemp` or `mkdtemp` (e.g. Windows).

private func _NSCreateTemporaryFile(_ template: String) throws -> (Int32, String) {
#if os(Windows)
  var buffer: [WCHAR] = Array<WCHAR>(repeating: 0, count: template.length)
  _ = template.withCString(encodedAs: UTF16.self, { wcscpy(&buffer, $0) })
  _ = _wmktemp(&buffer)

  let handle: HANDLE =
      CreateFileW(&buffer, GENERIC_READ | DWORD(GENERIC_WRITE),
                  DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                  nil, DWORD(OPEN_EXISTING), DWORD(FILE_ATTRIBUTE_NORMAL), nil)
  guard handle != INVALID_HANDLE_VALUE else { return (-1, "") }

  // Don't close handle, fd is transfered ownership
  let fd: Int32 = _open_osfhandle(intptr_t(bitPattern: handle), 0)
  let result: String = String(decodingCString: &buffer, as: UTF16.self)
  return (fd, result)
#else
  let count: Int = Int(PATH_MAX) + 1
  var buffer: [CChar] = Array<CChar>(repeating: 0, count: count)
  let _ = template.getFileSystemRepresentation(&buffer, maxLength: count)
  let fd: Int32 = mkstemp(&buffer)
  guard fd != -1 else { throw TempFileError(errno: errno) }
  let result: String = FileManager.default.string(withFileSystemRepresentation: buffer, length: strlen(buffer))
  return (fd, result)
#endif
}

private func _NSCreateTemporaryDirectory(_ template: String) throws -> String {
#if os(Windows)
  var buffer: [WCHAR] = Array<WCHAR>(repeating: 0, count: template.length)
  _ = template.withCString(encodedAs: UTF16.self, { wcscpy(&buffer, $0) })
  _ = _wmktemp(&buffer)
  let location: String = String(decodingCString: &buffer, as: UTF16.self)

  try FileManager.default.createDirectory(atPath: location, withIntermediateDirectories: false)
  return location
#else
  let count: Int = Int(PATH_MAX) + 1
  var buffer: [CChar] = Array<CChar>(repeating: 0, count: count)
  let _ = template.getFileSystemRepresentation(&buffer, maxLength: count)
  if TSCLibc.mkdtemp(&buffer) == nil {
    throw MakeDirectoryError(errno: errno)
  }
  return FileManager.default.string(withFileSystemRepresentation: buffer, length: strlen(buffer))
#endif
}

/// The closure argument of the `body` closue of `withTemporaryFile`.
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
        let path = self.dir.appending(RelativePath(prefix + ".XXXXXX" + suffix))

        let (fd, location) = try _NSCreateTemporaryFile(path.pathString)

        self.fd = fd
        self.path = AbsolutePath(location)

        fileHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    }
}

extension TemporaryFile: CustomStringConvertible {
    public var description: String {
        return "<TemporaryFile: \(path)>"
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
///             If `body` has a return value, that value is also used as the
///             return value for the `withTemporaryFile` function.
///
/// - Throws: TempFileError and rethrows all errors from `body`.
public func withTemporaryFile<Result>(
  dir: AbsolutePath? = nil, prefix: String = "TemporaryFile", suffix: String = "", deleteOnClose: Bool = true, _ body: (TemporaryFile) throws -> Result
) throws -> Result {
    let tempFile = try TemporaryFile(dir: dir, prefix: prefix, suffix: suffix)
    defer {
        if deleteOnClose {
            unlink(tempFile.path.pathString)
        }
    }
    return try body(tempFile)
}

// FIXME: This isn't right place to declare this, probably POSIX or merge with FileSystemError?
//
/// Contains the error which can be thrown while creating a directory using POSIX's mkdir.
public enum MakeDirectoryError: Swift.Error {
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
    // Construct path to the temporary directory.
    let templatePath = try determineTempDirectory(dir).appending(RelativePath(prefix + ".XXXXXX"))

    let location = try _NSCreateTemporaryDirectory(templatePath.pathString)
    let path = AbsolutePath(location)

    defer {
        let isEmptyDirectory: (String) -> Bool = { path in
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path) else { return false }
            return contents.isEmpty
        }

        if removeTreeOnDeinit || isEmptyDirectory(path.pathString) {
            _ = try? FileManager.default.removeItem(atPath: path.pathString)
        }
    }
    return try body(path)
}

