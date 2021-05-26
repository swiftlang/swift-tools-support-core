/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import class Foundation.ProcessInfo
import protocol Foundation.CustomNSError
import var Foundation.NSLocalizedDescriptionKey

import Foundation

@_implementationOnly import TSCclibc
import TSCLibc
import Dispatch

/// Process result data which is available after process termination.
public struct ProcessResult: CustomStringConvertible {

    public enum Error: Swift.Error {
        /// The output is not a valid UTF8 sequence.
        case illegalUTF8Sequence

        /// The process had a non zero exit.
        case nonZeroExit(ProcessResult)
    }

    public enum ExitStatus: Equatable {
        /// The process was terminated normally with a exit code.
        case terminated(code: Int32)
#if !os(Windows)
        /// The process was terminated due to a signal.
        case signalled(signal: Int32)
#endif
    }

    /// The arguments with which the process was launched.
    public let arguments: [String]

    /// The environment with which the process was launched.
    public let environment: [String: String]

    /// The exit status of the process.
    public let exitStatus: ExitStatus

    /// The output bytes of the process. Available only if the process was
    /// asked to redirect its output and no stdout output closure was set.
    public let output: Result<[UInt8], Swift.Error>

    /// The output bytes of the process. Available only if the process was
    /// asked to redirect its output and no stderr output closure was set.
    public let stderrOutput: Result<[UInt8], Swift.Error>

    /// Create an instance using a POSIX process exit status code and output result.
    ///
    /// See `waitpid(2)` for information on the exit status code.
    public init(
        arguments: [String],
        environment: [String: String],
        exitStatusCode: Int32,
        output: Result<[UInt8], Swift.Error>,
        stderrOutput: Result<[UInt8], Swift.Error>
    ) {
        let exitStatus: ExitStatus
      #if os(Windows)
        exitStatus = .terminated(code: exitStatusCode)
      #else
        if WIFSIGNALED(exitStatusCode) {
            exitStatus = .signalled(signal: WTERMSIG(exitStatusCode))
        } else {
            precondition(WIFEXITED(exitStatusCode), "unexpected exit status \(exitStatusCode)")
            exitStatus = .terminated(code: WEXITSTATUS(exitStatusCode))
        }
      #endif
        self.init(arguments: arguments, environment: environment, exitStatus: exitStatus, output: output,
            stderrOutput: stderrOutput)
    }

    /// Create an instance using an exit status and output result.
    public init(
        arguments: [String],
        environment: [String: String],
        exitStatus: ExitStatus,
        output: Result<[UInt8], Swift.Error>,
        stderrOutput: Result<[UInt8], Swift.Error>
    ) {
        self.arguments = arguments
        self.environment = environment
        self.output = output
        self.stderrOutput = stderrOutput
        self.exitStatus = exitStatus
    }

    /// Converts stdout output bytes to string, assuming they're UTF8.
    public func utf8Output() throws -> String {
        return String(decoding: try output.get(), as: Unicode.UTF8.self)
    }

    /// Converts stderr output bytes to string, assuming they're UTF8.
    public func utf8stderrOutput() throws -> String {
        return String(decoding: try stderrOutput.get(), as: Unicode.UTF8.self)
    }

    public var description: String {
        return """
            <ProcessResult: exit: \(exitStatus), output:
             \((try? utf8Output()) ?? "")
            >
            """
    }
}

/// Process allows spawning new subprocesses and working with them.
///
/// Note: This class is thread safe.
public final class Process: ObjectIdentifierProtocol {

    /// Errors when attempting to invoke a process
    public enum Error: Swift.Error {
        /// The program requested to be executed cannot be found on the existing search paths, or is not executable.
        case missingExecutableProgram(program: String)

        /// The current OS does not support the workingDirectory API.
        case workingDirectoryNotSupported
    }

    public enum OutputRedirection {
        /// Do not redirect the output
        case none
        /// Collect stdout and stderr output and provide it back via ProcessResult object. If redirectStderr is true,
        /// stderr be redirected to stdout.
        case collect(redirectStderr: Bool)
        /// Stream stdout and stderr via the corresponding closures. If redirectStderr is true, stderr be redirected to
        /// stdout.
        case stream(stdout: OutputClosure, stderr: OutputClosure, redirectStderr: Bool)

        /// Default collect OutputRedirection that defaults to not redirect stderr. Provided for API compatibility.
        public static let collect: OutputRedirection = .collect(redirectStderr: false)

        /// Default stream OutputRedirection that defaults to not redirect stderr. Provided for API compatibility.
        public static func stream(stdout: @escaping OutputClosure, stderr: @escaping OutputClosure) -> Self {
            return .stream(stdout: stdout, stderr: stderr, redirectStderr: false)
        }

        public var redirectsOutput: Bool {
            switch self {
            case .none:
                return false
            case .collect, .stream:
                return true
            }
        }

        public var outputClosures: (stdoutClosure: OutputClosure, stderrClosure: OutputClosure)? {
            switch self {
            case let .stream(stdoutClosure, stderrClosure, _):
                return (stdoutClosure: stdoutClosure, stderrClosure: stderrClosure)
            case .collect, .none:
                return nil
            }
        }

        public var redirectStderr: Bool {
            switch self {
            case let .collect(redirectStderr):
                return redirectStderr
            case let .stream(_, _, redirectStderr):
                return redirectStderr
            default:
                return false
            }
        }
    }

    /// Typealias for process id type.
  #if !os(Windows)
    public typealias ProcessID = pid_t
  #else
    public typealias ProcessID = DWORD
  #endif

    /// Typealias for stdout/stderr output closure.
    public typealias OutputClosure = ([UInt8]) -> Void

    /// Global default setting for verbose.
    public static var verbose = false

    /// If true, prints the subprocess arguments before launching it.
    public let verbose: Bool

    /// The current environment.
    @available(*, deprecated, message: "use ProcessEnv.vars instead")
    static public var env: [String: String] {
        return ProcessInfo.processInfo.environment
    }

    /// The arguments to execute.
    public let arguments: [String]

    /// The environment with which the process was executed.
    public let environment: [String: String]

    /// The path to the directory under which to run the process.
    public let workingDirectory: AbsolutePath?

    /// The process id of the spawned process, available after the process is launched.
    private var _process: Foundation.Process?
    public var processID: ProcessID {
        return ProcessID(_process?.processIdentifier ?? 0)
    }

    /// If the subprocess has launched.
    /// Note: This property is not protected by the serial queue because it is only mutated in `launch()`, which will be
    /// called only once.
    public private(set) var launched = false

    /// The result of the process execution. Available after process is terminated.
    public var result: ProcessResult? {
        return self.serialQueue.sync {
            self._result
        }
    }

    /// How process redirects its output.
    public let outputRedirection: OutputRedirection

    /// The result of the process execution. Available after process is terminated.
    private var _result: ProcessResult?

    /// If redirected, stdout result and reference to the thread reading the output.
    private var stdout: (result: Result<[UInt8], Swift.Error>, thread: Thread?) = (.success([]), nil)

    /// If redirected, stderr result and reference to the thread reading the output.
    private var stderr: (result: Result<[UInt8], Swift.Error>, thread: Thread?) = (.success([]), nil)

    /// Queue to protect concurrent reads.
    private let serialQueue = DispatchQueue(label: "org.swift.swiftpm.process")

    /// Queue to protect reading/writing on map of validated executables.
    private static let executablesQueue = DispatchQueue(
        label: "org.swift.swiftpm.process.findExecutable")

    /// Indicates if a new progress group is created for the child process.
    private let startNewProcessGroup: Bool

    /// Cache of validated executables.
    ///
    /// Key: Executable name or path.
    /// Value: Path to the executable, if found.
    static private var validatedExecutablesMap = [String: AbsolutePath?]()

    /// Create a new process instance.
    ///
    /// - Parameters:
    ///   - arguments: The arguments for the subprocess.
    ///   - environment: The environment to pass to subprocess. By default the current process environment
    ///     will be inherited.
    ///   - workingDirectory: The path to the directory under which to run the process.
    ///   - outputRedirection: How process redirects its output. Default value is .collect.
    ///   - verbose: If true, launch() will print the arguments of the subprocess before launching it.
    ///   - startNewProcessGroup: If true, a new progress group is created for the child making it
    ///     continue running even if the parent is killed or interrupted. Default value is true.
    @available(macOS 10.15, *)
    public init(
        arguments: [String],
        environment: [String: String] = ProcessEnv.vars,
        workingDirectory: AbsolutePath,
        outputRedirection: OutputRedirection = .collect,
        verbose: Bool = Process.verbose,
        startNewProcessGroup: Bool = true
    ) {
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.outputRedirection = outputRedirection
        self.verbose = verbose
        self.startNewProcessGroup = startNewProcessGroup
    }

    /// Create a new process instance.
    ///
    /// - Parameters:
    ///   - arguments: The arguments for the subprocess.
    ///   - environment: The environment to pass to subprocess. By default the current process environment
    ///     will be inherited.
    ///   - outputRedirection: How process redirects its output. Default value is .collect.
    ///   - verbose: If true, launch() will print the arguments of the subprocess before launching it.
    ///   - startNewProcessGroup: If true, a new progress group is created for the child making it
    ///     continue running even if the parent is killed or interrupted. Default value is true.
    public init(
        arguments: [String],
        environment: [String: String] = ProcessEnv.vars,
        outputRedirection: OutputRedirection = .collect,
        verbose: Bool = Process.verbose,
        startNewProcessGroup: Bool = true
    ) {
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = nil
        self.outputRedirection = outputRedirection
        self.verbose = verbose
        self.startNewProcessGroup = startNewProcessGroup
    }

    /// Returns the path of the the given program if found in the search paths.
    ///
    /// The program can be executable name, relative path or absolute path.
    public static func findExecutable(
        _ program: String,
        workingDirectory: AbsolutePath? = nil
    ) -> AbsolutePath? {
        if let abs = try? AbsolutePath(validating: program) {
            return abs
        }
        let cwdOpt = workingDirectory ?? localFileSystem.currentWorkingDirectory
        // The program might be a multi-component relative path.
        if let rel = try? RelativePath(validating: program), rel.components.count > 1 {
            if let cwd = cwdOpt {
                let abs = cwd.appending(rel)
                if localFileSystem.isExecutableFile(abs) {
                    return abs
                }
            }
            return nil
        }
        // From here on out, the program is an executable name, i.e. it doesn't contain a "/"
        let lookup: () -> AbsolutePath? = {
            let envSearchPaths = getEnvSearchPaths(
                pathString: ProcessEnv.path,
                currentWorkingDirectory: cwdOpt
            )
            let value = lookupExecutablePath(
                filename: program,
                currentWorkingDirectory: cwdOpt,
                searchPaths: envSearchPaths
            )
            return value
        }
        // This should cover the most common cases, i.e. when the cache is most helpful.
        if workingDirectory == localFileSystem.currentWorkingDirectory {
            return Process.executablesQueue.sync {
                if let value = Process.validatedExecutablesMap[program] {
                    return value
                }
                let value = lookup()
                Process.validatedExecutablesMap[program] = value
                return value
            }
        } else {
            return lookup()
        }
    }

    /// Launch the subprocess. Returns a WritableByteStream object that can be used to communicate to the process's
    /// stdin. If needed, the stream can be closed using the close() API. Otherwise, the stream will be closed
    /// automatically.
    @discardableResult
    public func launch() throws -> WritableByteStream {
        precondition(arguments.count > 0 && !arguments[0].isEmpty, "Need at least one argument to launch the process.")
        precondition(!launched, "It is not allowed to launch the same process object again.")

        // Set the launch bool to true.
        launched = true

        // Print the arguments if we are verbose.
        if self.verbose {
            stdoutStream <<< arguments.map({ $0.spm_shellEscaped() }).joined(separator: " ") <<< "\n"
            stdoutStream.flush()
        }

        // Look for executable.
        let executable = arguments[0]
        guard let executablePath = Process.findExecutable(executable, workingDirectory: workingDirectory) else {
            throw Process.Error.missingExecutableProgram(program: executable)
        }

        _process = Foundation.Process()
        _process?.arguments = Array(arguments.dropFirst()) // Avoid including the executable URL twice.
        _process?.executableURL = executablePath.asURL
        _process?.environment = environment

        let stdinPipe = Pipe()
        _process?.standardInput = stdinPipe

        if outputRedirection.redirectsOutput {
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            stdoutPipe.fileHandleForReading.readabilityHandler = { (fh : FileHandle) -> Void in
                let contents = fh.readDataToEndOfFile()
                self.outputRedirection.outputClosures?.stdoutClosure([UInt8](contents))
                if case .success(let data) = self.stdout.result {
                    self.stdout.result = .success(data + contents)
                }
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { (fh : FileHandle) -> Void in
                let contents = fh.readDataToEndOfFile()
                self.outputRedirection.outputClosures?.stderrClosure([UInt8](contents))
                if case .success(let data) = self.stderr.result {
                    self.stderr.result = .success(data + contents)
                }
            }
            _process?.standardOutput = stdoutPipe
            _process?.standardError = stderrPipe
        }

        try _process?.run()
        return stdinPipe.fileHandleForWriting
    }

    /// Blocks the calling process until the subprocess finishes execution.
    @discardableResult
    public func waitUntilExit() throws -> ProcessResult {
        precondition(_process != nil, "The process is not yet launched.")
        let p = _process!
        p.waitUntilExit()
        stdout.thread?.join()
        stderr.thread?.join()

        let executionResult = ProcessResult(
            arguments: arguments,
            environment: environment,
            exitStatusCode: p.terminationStatus,
            output: stdout.result,
            stderrOutput: stderr.result
        )
        return executionResult
    }

    /// Send a signal to the process.
    ///
    /// Note: This will signal all processes in the process group.
    public func signal(_ signal: Int32) {
      #if os(Windows)
        if signal == SIGINT {
          _process?.interrupt()
        } else {
          _process?.terminate()
        }
      #else
        assert(launched, "The process is not yet launched.")
        _ = TSCLibc.kill(startNewProcessGroup ? -processID : processID, signal)
      #endif
    }
}

extension Process {
    /// Execute a subprocess and block until it finishes execution
    ///
    /// - Parameters:
    ///   - arguments: The arguments for the subprocess.
    ///   - environment: The environment to pass to subprocess. By default the current process environment
    ///     will be inherited.
    /// - Returns: The process result.
    @discardableResult
    static public func popen(arguments: [String], environment: [String: String] = ProcessEnv.vars) throws -> ProcessResult {
        let process = Process(arguments: arguments, environment: environment, outputRedirection: .collect)
        try process.launch()
        return try process.waitUntilExit()
    }

    @discardableResult
    static public func popen(args: String..., environment: [String: String] = ProcessEnv.vars) throws -> ProcessResult {
        return try Process.popen(arguments: args, environment: environment)
    }

    /// Execute a subprocess and get its (UTF-8) output if it has a non zero exit.
    ///
    /// - Parameters:
    ///   - arguments: The arguments for the subprocess.
    ///   - environment: The environment to pass to subprocess. By default the current process environment
    ///     will be inherited.
    /// - Returns: The process output (stdout + stderr).
    @discardableResult
    static public func checkNonZeroExit(arguments: [String], environment: [String: String] = ProcessEnv.vars) throws -> String {
        let process = Process(arguments: arguments, environment: environment, outputRedirection: .collect)
        try process.launch()
        let result = try process.waitUntilExit()
        // Throw if there was a non zero termination.
        guard result.exitStatus == .terminated(code: 0) else {
            throw ProcessResult.Error.nonZeroExit(result)
        }
        return try result.utf8Output()
    }

    @discardableResult
    static public func checkNonZeroExit(args: String..., environment: [String: String] = ProcessEnv.vars) throws -> String {
        return try checkNonZeroExit(arguments: args, environment: environment)
    }

    public convenience init(args: String..., environment: [String: String] = ProcessEnv.vars, outputRedirection: OutputRedirection = .collect) {
        self.init(arguments: args, environment: environment, outputRedirection: outputRedirection)
    }
}

// MARK: - Private helpers

#if !os(Windows)
private func WIFEXITED(_ status: Int32) -> Bool {
    return _WSTATUS(status) == 0
}

private func _WSTATUS(_ status: Int32) -> Int32 {
    return status & 0x7f
}

private func WIFSIGNALED(_ status: Int32) -> Bool {
    return (_WSTATUS(status) != 0) && (_WSTATUS(status) != 0x7f)
}

private func WEXITSTATUS(_ status: Int32) -> Int32 {
    return (status >> 8) & 0xff
}

private func WTERMSIG(_ status: Int32) -> Int32 {
    return status & 0x7f
}

extension Process.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .missingExecutableProgram(let program):
            return "could not find executable for '\(program)'"
        case .workingDirectoryNotSupported:
            return "workingDirectory is not supported in this platform"
        }
    }
}

extension Process.Error: CustomNSError {
    public var errorUserInfo: [String : Any] {
        return [NSLocalizedDescriptionKey: self.description]
    }
}

#endif

extension ProcessResult.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .illegalUTF8Sequence:
            return "illegal UTF8 sequence output"
        case .nonZeroExit(let result):
            let stream = BufferedOutputByteStream()
            switch result.exitStatus {
            case .terminated(let code):
                stream <<< "terminated(\(code)): "
#if !os(Windows)
            case .signalled(let signal):
                stream <<< "signalled(\(signal)): "
#endif
            }

            // Strip sandbox information from arguments to keep things pretty.
            var args = result.arguments
            // This seems a little fragile.
            if args.first == "sandbox-exec", args.count > 3 {
                args = args.suffix(from: 3).map({$0})
            }
            stream <<< args.map({ $0.spm_shellEscaped() }).joined(separator: " ")

            // Include the output, if present.
            if let output = try? result.utf8Output() + result.utf8stderrOutput() {
                // We indent the output to keep it visually separated from everything else.
                let indentation = "    "
                stream <<< " output:\n" <<< indentation <<< output.replacingOccurrences(of: "\n", with: "\n" + indentation)
                if !output.hasSuffix("\n") {
                    stream <<< "\n"
                }
            }

            return stream.bytes.description
        }
    }
}

#if os(Windows)
extension FileHandle: WritableByteStream {
    public var position: Int {
        return Int(offsetInFile)
    }

    public func write(_ byte: UInt8) {
        write(Data([byte]))
    }

    public func write<C: Collection>(_ bytes: C) where C.Element == UInt8 {
        write(Data(bytes))
    }

    public func flush() {
        synchronizeFile()
    }

    public func close() throws {
        closeFile()
    }
}
#endif
