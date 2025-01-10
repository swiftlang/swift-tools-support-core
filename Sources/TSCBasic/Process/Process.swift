/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import protocol Foundation.CustomNSError
import var Foundation.NSLocalizedDescriptionKey
import class Foundation.NSLock
import class Foundation.ProcessInfo

#if os(Windows)
import Foundation
#endif

@_implementationOnly import TSCclibc
import TSCLibc
import Dispatch

import _Concurrency

/// Process result data which is available after process termination.
public struct ProcessResult: CustomStringConvertible, Sendable {

    public enum Error: Swift.Error, Sendable {
        /// The output is not a valid UTF8 sequence.
        case illegalUTF8Sequence

        /// The process had a non zero exit.
        case nonZeroExit(ProcessResult)

        /// The process failed with a `SystemError` (this is used to still provide context on the process that was launched).
        case systemError(arguments: [String], underlyingError: Swift.Error)
    }

    public enum ExitStatus: Equatable, Sendable {
        /// The process was terminated normally with a exit code.
        case terminated(code: Int32)
#if os(Windows)
        /// The process was terminated abnormally.
        case abnormal(exception: UInt32)
#else
        /// The process was terminated due to a signal.
        case signalled(signal: Int32)
#endif
    }

    /// The arguments with which the process was launched.
    public let arguments: [String]

    /// The environment with which the process was launched.
    public let environmentBlock: ProcessEnvironmentBlock

    @available(*, deprecated, renamed: "env")
    public var environment: [String:String] {
        Dictionary<String, String>(uniqueKeysWithValues: self.environmentBlock.map { ($0.key.value, $0.value) })
    }

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
        environmentBlock: ProcessEnvironmentBlock,
        exitStatusCode: Int32,
        normal: Bool,
        output: Result<[UInt8], Swift.Error>,
        stderrOutput: Result<[UInt8], Swift.Error>
    ) {
        let exitStatus: ExitStatus
      #if os(Windows)
        if normal {
            exitStatus = .terminated(code: exitStatusCode)
        } else {
            exitStatus = .abnormal(exception: UInt32(exitStatusCode))
        }
      #else
        if WIFSIGNALED(exitStatusCode) {
            exitStatus = .signalled(signal: WTERMSIG(exitStatusCode))
        } else {
            precondition(WIFEXITED(exitStatusCode), "unexpected exit status \(exitStatusCode)")
            exitStatus = .terminated(code: WEXITSTATUS(exitStatusCode))
        }
      #endif
        self.init(arguments: arguments, environmentBlock: environmentBlock, exitStatus: exitStatus, output: output, stderrOutput: stderrOutput)
    }

    @available(*, deprecated, message: "use `init(arguments:environmentBlock:exitStatusCode:output:stderrOutput:)`")
    public init(
        arguments: [String],
        environment: [String:String],
        exitStatusCode: Int32,
        normal: Bool,
        output: Result<[UInt8], Swift.Error>,
        stderrOutput: Result<[UInt8], Swift.Error>
    ) {
        self.init(
            arguments: arguments,
            environmentBlock: .init(environment),
            exitStatusCode: exitStatusCode,
            normal: normal,
            output: output,
            stderrOutput: stderrOutput
        )
    }

    /// Create an instance using an exit status and output result.
    public init(
        arguments: [String],
        environmentBlock: ProcessEnvironmentBlock,
        exitStatus: ExitStatus,
        output: Result<[UInt8], Swift.Error>,
        stderrOutput: Result<[UInt8], Swift.Error>
    ) {
        self.arguments = arguments
        self.environmentBlock = environmentBlock
        self.output = output
        self.stderrOutput = stderrOutput
        self.exitStatus = exitStatus
    }

    @available(*, deprecated, message: "use `init(arguments:environmentBlock:exitStatus:output:stderrOutput:)`")
    public init(
        arguments: [String],
        environment: [String:String],
        exitStatus: ExitStatus,
        output: Result<[UInt8], Swift.Error>,
        stderrOutput: Result<[UInt8], Swift.Error>
    ) {
        self.init(
            arguments: arguments,
            environmentBlock: .init(environment),
            exitStatus: exitStatus,
            output: output,
            stderrOutput: stderrOutput
        )
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

extension Process: @unchecked Sendable {}

extension DispatchQueue {
    // a shared concurrent queue for running concurrent asynchronous operations
    static let processConcurrent = DispatchQueue(
        label: "swift.org.swift-tsc.process.concurrent",
        attributes: .concurrent
    )
}

/// Process allows spawning new subprocesses and working with them.
///
/// Note: This class is thread safe.
public final class Process {
    /// Errors when attempting to invoke a process
    public enum Error: Swift.Error, Sendable {
        /// The program requested to be executed cannot be found on the existing search paths, or is not executable.
        case missingExecutableProgram(program: String)

        /// The current OS does not support the workingDirectory API.
        case workingDirectoryNotSupported

        /// The stdin could not be opened.
        case stdinUnavailable
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

    // process execution mutable state
    private enum State {
        case idle
        case readingOutput(sync: DispatchGroup)
        case outputReady(stdout: Result<[UInt8], Swift.Error>, stderr: Result<[UInt8], Swift.Error>)
        case complete(ProcessResult)
        case failed(Swift.Error)
    }

    /// Typealias for process id type.
  #if !os(Windows)
    public typealias ProcessID = pid_t
  #else
    public typealias ProcessID = DWORD
  #endif

    /// Typealias for stdout/stderr output closure.
    public typealias OutputClosure = ([UInt8]) -> Void

    /// Typealias for logging handling closure
    public typealias LoggingHandler = (String) -> Void

    private static var _loggingHandler: LoggingHandler?
    private static let loggingHandlerLock = NSLock()

    /// Global logging handler. Use with care! preferably use instance level instead of setting one globally.
    @available(*, deprecated, message: "use instance level `loggingHandler` passed via `init` instead of setting one globally.")
    public static var loggingHandler: LoggingHandler? {
        get {
            Self.loggingHandlerLock.withLock {
                self._loggingHandler
            }
        } set {
            Self.loggingHandlerLock.withLock {
                self._loggingHandler = newValue
            }
        }
    }

    public let loggingHandler: LoggingHandler?

    /// The current environment.
    @available(*, deprecated, message: "use ProcessEnv.vars instead")
    static public var env: [String: String] {
        ProcessEnv.vars
    }

    /// The arguments to execute.
    public let arguments: [String]

    /// The environment with which the process was executed.
    @available(*, deprecated, message: "use `environmentBlock` instead")
    public var environment: [String:String] {
        Dictionary<String, String>(uniqueKeysWithValues: environmentBlock.map { ($0.key.value, $0.value) })
    }

    public let environmentBlock: ProcessEnvironmentBlock

    /// The path to the directory under which to run the process.
    public let workingDirectory: AbsolutePath?

    /// The process id of the spawned process, available after the process is launched.
  #if os(Windows)
    private var _process: Foundation.Process?
    public var processID: ProcessID {
        return DWORD(_process?.processIdentifier ?? 0)
    }
  #else
    public private(set) var processID = ProcessID()
  #endif

    // process execution mutable state
    private var state: State = .idle
    private let stateLock = NSLock()

    private static let sharedCompletionQueue = DispatchQueue(label: "org.swift.tools-support-core.process-completion")
    private var completionQueue = Process.sharedCompletionQueue

    /// The result of the process execution. Available after process is terminated.
    /// This will block while the process is awaiting result
    @available(*, deprecated, message: "use waitUntilExit instead")
    public var result: ProcessResult? {
        return self.stateLock.withLock {
            switch self.state {
            case .complete(let result):
                return result
            default:
                return nil
            }
        }
    }

    // ideally we would use the state for this, but we need to access it while the waitForExit is locking state
    private var _launched = false
    private let launchedLock = NSLock()

    public var launched: Bool {
        return self.launchedLock.withLock {
            return self._launched
        }
    }

    /// How process redirects its output.
    public let outputRedirection: OutputRedirection

    /// Indicates if a new progress group is created for the child process.
    private let startNewProcessGroup: Bool

    /// Cache of validated executables.
    ///
    /// Key: Executable name or path.
    /// Value: Path to the executable, if found.
    private static var validatedExecutablesMap = [String: AbsolutePath?]()
    private static let validatedExecutablesMapLock = NSLock()

    /// Create a new process instance.
    ///
    /// - Parameters:
    ///   - arguments: The arguments for the subprocess.
    ///   - environment: The environment to pass to subprocess. By default the current process environment
    ///     will be inherited.
    ///   - workingDirectory: The path to the directory under which to run the process.
    ///   - outputRedirection: How process redirects its output. Default value is .collect.
    ///   - startNewProcessGroup: If true, a new progress group is created for the child making it
    ///     continue running even if the parent is killed or interrupted. Default value is true.
    ///   - loggingHandler: Handler for logging messages
    ///
    public init(
        arguments: [String],
        environmentBlock: ProcessEnvironmentBlock = ProcessEnv.block,
        workingDirectory: AbsolutePath,
        outputRedirection: OutputRedirection = .collect,
        startNewProcessGroup: Bool = true,
        loggingHandler: LoggingHandler? = .none
    ) {
        self.arguments = arguments
        self.environmentBlock = environmentBlock
        self.workingDirectory = workingDirectory
        self.outputRedirection = outputRedirection
        self.startNewProcessGroup = startNewProcessGroup
        self.loggingHandler = loggingHandler ?? Process.loggingHandler
    }

    @_disfavoredOverload
    @available(macOS 10.15, *)
    @available(*, deprecated, renamed: "init(arguments:environmentBlock:workingDirectory:outputRedirection:startNewProcessGroup:loggingHandler:)")
    public convenience init(
        arguments: [String],
        environment: [String:String] = ProcessEnv.vars,
        workingDirectory: AbsolutePath,
        outputRedirection: OutputRedirection = .collect,
        startNewProcessGroup: Bool = true,
        loggingHandler: LoggingHandler? = .none
    ) {
        self.init(
            arguments: arguments,
            environmentBlock: .init(environment),
            workingDirectory: workingDirectory,
            outputRedirection: outputRedirection,
            startNewProcessGroup: startNewProcessGroup,
            loggingHandler: loggingHandler
        )
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
    ///   - loggingHandler: Handler for logging messages
    public init(arguments: [String], environmentBlock: ProcessEnvironmentBlock = ProcessEnv.block, outputRedirection: OutputRedirection = .collect, startNewProcessGroup: Bool = true, loggingHandler: LoggingHandler? = .none) {
        self.arguments = arguments
        self.environmentBlock = environmentBlock
        self.workingDirectory = nil
        self.outputRedirection = outputRedirection
        self.startNewProcessGroup = startNewProcessGroup
        self.loggingHandler = loggingHandler ?? Process.loggingHandler
    }

    @_disfavoredOverload
    @available(*, deprecated, renamed: "init(arguments:environmentBlock:outputRedirection:startNewProcessGroup:loggingHandler:)")
    public convenience init(
        arguments: [String],
        environment: [String:String] = ProcessEnv.vars,
        outputRedirection: OutputRedirection = .collect,
        startNewProcessGroup: Bool = true,
        loggingHandler: LoggingHandler? = .none
    ) {
        self.init(
            arguments: arguments,
            environmentBlock: .init(environment),
            outputRedirection: outputRedirection,
            startNewProcessGroup: startNewProcessGroup,
            loggingHandler: loggingHandler
        )
    }

    public convenience init(
        args: String...,
        environmentBlock: ProcessEnvironmentBlock = ProcessEnv.block,
        outputRedirection: OutputRedirection = .collect,
        loggingHandler: LoggingHandler? = .none
    ) {
        self.init(
            arguments: args,
            environmentBlock: environmentBlock,
            outputRedirection: outputRedirection,
            loggingHandler: loggingHandler
        )
    }

    @_disfavoredOverload
    @available(*, deprecated, renamed: "init(args:environmentBlock:outputRedirection:loggingHandler:)")
    public convenience init(
        args: String...,
        environment: [String: String] = ProcessEnv.vars,
        outputRedirection: OutputRedirection = .collect,
        loggingHandler: LoggingHandler? = .none
    ) {
        self.init(
            arguments: args,
            environmentBlock: .init(environment),
            outputRedirection: outputRedirection,
            loggingHandler: loggingHandler
        )
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
                let abs = AbsolutePath(cwd, rel)
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
            return Process.validatedExecutablesMapLock.withLock {
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

        self.launchedLock.withLock {
            precondition(!self._launched, "It is not allowed to launch the same process object again.")
            self._launched = true
        }

        // Print the arguments if we are verbose.
        if let loggingHandler = self.loggingHandler {
            loggingHandler(arguments.map({ $0.spm_shellEscaped() }).joined(separator: " "))
        }

        // Look for executable.
        let executable = arguments[0]
        guard let executablePath = Process.findExecutable(executable, workingDirectory: workingDirectory) else {
            throw Process.Error.missingExecutableProgram(program: executable)
        }

    #if os(Windows)
        let process = Foundation.Process()
        _process = process
        process.arguments = Array(arguments.dropFirst()) // Avoid including the executable URL twice.
        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory.asURL
        }
        process.executableURL = executablePath.asURL
        process.environment = Dictionary<String, String>(uniqueKeysWithValues: environmentBlock.map { ($0.key.value, $0.value) })

        let stdinPipe = Pipe()
        process.standardInput = stdinPipe

        let group = DispatchGroup()

        var stdout: [UInt8] = []
        let stdoutLock = Lock()

        var stderr: [UInt8] = []
        let stderrLock = Lock()

        if outputRedirection.redirectsOutput {
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            group.enter()
            stdoutPipe.fileHandleForReading.readabilityHandler = { (fh : FileHandle) -> Void in
                let data = (try? fh.read(upToCount: Int.max)) ?? Data()
                if (data.count == 0) {
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    group.leave()
                } else {
                    let contents = data.withUnsafeBytes { Array<UInt8>($0) }
                    self.outputRedirection.outputClosures?.stdoutClosure(contents)
                    stdoutLock.withLock {
                        stdout += contents
                    }
                }
            }

            group.enter()
            stderrPipe.fileHandleForReading.readabilityHandler = { (fh : FileHandle) -> Void in
                let data = (try? fh.read(upToCount: Int.max)) ?? Data()
                if (data.count == 0) {
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    group.leave()
                } else {
                    let contents = data.withUnsafeBytes { Array<UInt8>($0) }
                    self.outputRedirection.outputClosures?.stderrClosure(contents)
                    stderrLock.withLock {
                        stderr += contents
                    }
                }
            }

            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
        }

        // first set state then start reading threads
        let sync = DispatchGroup()
        sync.enter()
        self.stateLock.withLock {
            self.state = .readingOutput(sync: sync)
        }

        group.notify(queue: self.completionQueue) {
            self.stateLock.withLock {
                self.state = .outputReady(stdout: .success(stdout), stderr: .success(stderr))
            }
            sync.leave()
        }

        try process.run()
        return stdinPipe.fileHandleForWriting
    #elseif (!canImport(Darwin) || os(macOS))
        // Initialize the spawn attributes.
      #if canImport(Darwin) || os(Android) || os(OpenBSD) || os(FreeBSD)
        var attributes: posix_spawnattr_t? = nil
      #else
        var attributes = posix_spawnattr_t()
      #endif
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }

        // Unmask all signals.
        var noSignals = sigset_t()
        sigemptyset(&noSignals)
        posix_spawnattr_setsigmask(&attributes, &noSignals)

        // Reset all signals to default behavior.
      #if canImport(Darwin)
        var mostSignals = sigset_t()
        sigfillset(&mostSignals)
        sigdelset(&mostSignals, SIGKILL)
        sigdelset(&mostSignals, SIGSTOP)
        posix_spawnattr_setsigdefault(&attributes, &mostSignals)
      #else
        // On Linux, this can only be used to reset signals that are legal to
        // modify, so we have to take care about the set we use.
        var mostSignals = sigset_t()
        sigemptyset(&mostSignals)
        for i in 1 ..< SIGSYS {
            if i == SIGKILL || i == SIGSTOP {
                continue
            }
            sigaddset(&mostSignals, i)
        }
        posix_spawnattr_setsigdefault(&attributes, &mostSignals)
      #endif

        // Set the attribute flags.
        var flags = POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF
        if startNewProcessGroup {
            // Establish a separate process group.
            flags |= POSIX_SPAWN_SETPGROUP
            posix_spawnattr_setpgroup(&attributes, 0)
        }

        posix_spawnattr_setflags(&attributes, Int16(flags))

        // Setup the file actions.
      #if canImport(Darwin) || os(Android) || os(OpenBSD) || os(FreeBSD)
        var fileActions: posix_spawn_file_actions_t? = nil
      #else
        var fileActions = posix_spawn_file_actions_t()
      #endif
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        if let workingDirectory = workingDirectory?.pathString {
          #if canImport(Darwin)
            // The only way to set a workingDirectory is using an availability-gated initializer, so we don't need
            // to handle the case where the posix_spawn_file_actions_addchdir_np method is unavailable. This check only
            // exists here to make the compiler happy.
            if #available(macOS 10.15, *) {
                posix_spawn_file_actions_addchdir_np(&fileActions, workingDirectory)
            }
          #elseif os(FreeBSD)
                posix_spawn_file_actions_addchdir_np(&fileActions, workingDirectory)
          #elseif os(Linux)
            guard SPM_posix_spawn_file_actions_addchdir_np_supported() else {
                throw Process.Error.workingDirectoryNotSupported
            }

            SPM_posix_spawn_file_actions_addchdir_np(&fileActions, workingDirectory)
          #else
            throw Process.Error.workingDirectoryNotSupported
          #endif
        }

        var stdinPipe: [Int32] = [-1, -1]
        try open(pipe: &stdinPipe)

        guard let fp = fdopen(stdinPipe[1], "wb") else {
            throw Process.Error.stdinUnavailable
        }
        let stdinStream = try LocalFileOutputByteStream(filePointer: fp, closeOnDeinit: true)

        // Dupe the read portion of the remote to 0.
        posix_spawn_file_actions_adddup2(&fileActions, stdinPipe[0], 0)

        // Close the other side's pipe since it was dupped to 0.
        posix_spawn_file_actions_addclose(&fileActions, stdinPipe[0])
        posix_spawn_file_actions_addclose(&fileActions, stdinPipe[1])

        var outputPipe: [Int32] = [-1, -1]
        var stderrPipe: [Int32] = [-1, -1]
        if outputRedirection.redirectsOutput {
            // Open the pipe.
            try open(pipe: &outputPipe)

            // Open the write end of the pipe.
            posix_spawn_file_actions_adddup2(&fileActions, outputPipe[1], 1)

            // Close the other ends of the pipe since they were dupped to 1.
            posix_spawn_file_actions_addclose(&fileActions, outputPipe[0])
            posix_spawn_file_actions_addclose(&fileActions, outputPipe[1])

            if outputRedirection.redirectStderr {
                // If merged was requested, send stderr to stdout.
                posix_spawn_file_actions_adddup2(&fileActions, 1, 2)
            } else {
                // If no redirect was requested, open the pipe for stderr.
                try open(pipe: &stderrPipe)
                posix_spawn_file_actions_adddup2(&fileActions, stderrPipe[1], 2)

                // Close the other ends of the pipe since they were dupped to 2.
                posix_spawn_file_actions_addclose(&fileActions, stderrPipe[0])
                posix_spawn_file_actions_addclose(&fileActions, stderrPipe[1])
            }
        } else {
            posix_spawn_file_actions_adddup2(&fileActions, 1, 1)
            posix_spawn_file_actions_adddup2(&fileActions, 2, 2)
        }

        var resolvedArgs = arguments
        if workingDirectory != nil {
            resolvedArgs[0] = executablePath.pathString
        }
        let argv = CStringArray(resolvedArgs)
        let env = CStringArray(environment.map({ "\($0.0)=\($0.1)" }))
        let rv = posix_spawnp(&processID, argv.cArray[0]!, &fileActions, &attributes, argv.cArray, env.cArray)

        guard rv == 0 else {
            throw SystemError.posix_spawn(rv, arguments)
        }

        do {
            // Close the local read end of the input pipe.
            try close(fd: stdinPipe[0])

            let group = DispatchGroup()
            if !outputRedirection.redirectsOutput {
                // no stdout or stderr in this case
                self.stateLock.withLock {
                    self.state = .outputReady(stdout: .success([]), stderr: .success([]))
                }
            } else {
                var pending: Result<[UInt8], Swift.Error>?
                let pendingLock = NSLock()

                let outputClosures = outputRedirection.outputClosures

                // Close the local write end of the output pipe.
                try close(fd: outputPipe[1])

                // Create a thread and start reading the output on it.
                group.enter()
                let stdoutThread = Thread { [weak self] in
                    if let readResult = self?.readOutput(onFD: outputPipe[0], outputClosure: outputClosures?.stdoutClosure) {
                        pendingLock.withLock {
                            if let stderrResult = pending {
                                self?.stateLock.withLock {
                                    self?.state = .outputReady(stdout: readResult, stderr: stderrResult)
                                }
                            } else  {
                                pending = readResult
                            }
                        }
                        group.leave()
                    } else if let stderrResult = (pendingLock.withLock { pending }) {
                        // TODO: this is more of an error
                        self?.stateLock.withLock {
                            self?.state = .outputReady(stdout: .success([]), stderr: stderrResult)
                        }
                        group.leave()
                    }
                }

                // Only schedule a thread for stderr if no redirect was requested.
                var stderrThread: Thread? = nil
                if !outputRedirection.redirectStderr {
                    // Close the local write end of the stderr pipe.
                    try close(fd: stderrPipe[1])

                    // Create a thread and start reading the stderr output on it.
                    group.enter()
                    stderrThread = Thread { [weak self] in
                        if let readResult = self?.readOutput(onFD: stderrPipe[0], outputClosure: outputClosures?.stderrClosure) {
                            pendingLock.withLock {
                                if let stdoutResult = pending {
                                    self?.stateLock.withLock {
                                        self?.state = .outputReady(stdout: stdoutResult, stderr: readResult)
                                    }
                                } else {
                                    pending = readResult
                                }
                            }
                            group.leave()
                        } else if let stdoutResult = (pendingLock.withLock { pending }) {
                            // TODO: this is more of an error
                            self?.stateLock.withLock {
                                self?.state = .outputReady(stdout: stdoutResult, stderr: .success([]))
                            }
                            group.leave()
                        }
                    }
                } else {
                    pendingLock.withLock {
                        pending = .success([])  // no stderr in this case
                    }
                }

                // first set state then start reading threads
                self.stateLock.withLock {
                    self.state = .readingOutput(sync: group)
                }

                stdoutThread.start()
                stderrThread?.start()
            }

            return stdinStream
        } catch {
            throw ProcessResult.Error.systemError(arguments: arguments, underlyingError: error)
        }
    #else
        preconditionFailure("Process spawning is not available")
    #endif // POSIX implementation
    }

    /// Executes the process I/O state machine, returning the result when finished.
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    @discardableResult
    public func waitUntilExit() async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.processConcurrent.async {
                self.waitUntilExit(continuation.resume(with:))
            }
        }
    }

    /// Blocks the calling process until the subprocess finishes execution.
    @available(*, noasync)
    @discardableResult
    public func waitUntilExit() throws -> ProcessResult {
        let group = DispatchGroup()
        group.enter()
        var processResult : Result<ProcessResult, Swift.Error>?
        self.waitUntilExit() { result in
            processResult = result
            group.leave()
        }
        group.wait()
        return try processResult.unsafelyUnwrapped.get()
    }

    /// Executes the process I/O state machine, calling completion block when finished.
    private func waitUntilExit(_ completion: @escaping (Result<ProcessResult, Swift.Error>) -> Void) {
        self.stateLock.lock()
        switch self.state {
        case .idle:
            defer { self.stateLock.unlock() }
            preconditionFailure("The process is not yet launched.")
        case .complete(let result):
            self.stateLock.unlock()
            completion(.success(result))
        case .failed(let error):
            self.stateLock.unlock()
            completion(.failure(error))
        case .readingOutput(let sync):
            self.stateLock.unlock()
            sync.notify(queue: self.completionQueue) {
                self.waitUntilExit(completion)
            }
        case .outputReady(let stdoutResult, let stderrResult):
            defer { self.stateLock.unlock() }
            // Wait until process finishes execution.
          #if os(Windows)
            precondition(_process != nil, "The process is not yet launched.")
            let p = _process!
            p.waitUntilExit()
            let exitStatusCode = p.terminationStatus
            let normalExit = p.terminationReason == .exit
          #else
            var exitStatusCode: Int32 = 0
            var result = waitpid(processID, &exitStatusCode, 0)
            while result == -1 && errno == EINTR {
                result = waitpid(processID, &exitStatusCode, 0)
            }
            if result == -1 {
                self.state = .failed(SystemError.waitpid(errno))
            }
            let normalExit = !WIFSIGNALED(result)
          #endif

            // Construct the result.
            let executionResult = ProcessResult(
                arguments: arguments,
                environmentBlock: environmentBlock,
                exitStatusCode: exitStatusCode,
                normal: normalExit,
                output: stdoutResult,
                stderrOutput: stderrResult
            )
            self.state = .complete(executionResult)
            self.completionQueue.async {
                self.waitUntilExit(completion)
            }
        }
    }

  #if !os(Windows)
    /// Reads the given fd and returns its result.
    ///
    /// Closes the fd before returning.
    private func readOutput(onFD fd: Int32, outputClosure: OutputClosure?) -> Result<[UInt8], Swift.Error> {
        // Read all of the data from the output pipe.
        let N = 4096
        var buf = [UInt8](repeating: 0, count: N + 1)

        var out = [UInt8]()
        var error: Swift.Error? = nil
        loop: while true {
            let n = read(fd, &buf, N)
            switch n {
            case  -1:
                if errno == EINTR {
                    continue
                } else {
                    error = SystemError.read(errno)
                    break loop
                }
            case 0:
                // Close the read end of the output pipe.
                // We should avoid closing the read end of the pipe in case
                // -1 because the child process may still have content to be
                // flushed into the write end of the pipe. If the read end of the
                // pipe is closed, then a write will cause a SIGPIPE signal to
                // be generated for the calling process.  If the calling process is
                // ignoring this signal, then write fails with the error EPIPE.
                close(fd)
                break loop
            default:
                let data = buf[0..<n]
                if let outputClosure = outputClosure {
                    outputClosure(Array(data))
                } else {
                    out += data
                }
            }
        }
        // Construct the output result.
        return error.map(Result.failure) ?? .success(out)
    }
  #endif

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
        assert(self.launched, "The process is not yet launched.")
        _ = TSCLibc.kill(startNewProcessGroup ? -processID : processID, signal)
      #endif
    }
}

extension Process {
    /// Execute a subprocess and returns the result when it finishes execution
    ///
    /// - Parameters:
    ///   - arguments: The arguments for the subprocess.
    ///   - environment: The environment to pass to subprocess. By default the current process environment
    ///     will be inherited.
    ///   - loggingHandler: Handler for logging messages
    static public func popen(
        arguments: [String],
        environmentBlock: ProcessEnvironmentBlock = ProcessEnv.block,
        loggingHandler: LoggingHandler? = .none
    ) async throws -> ProcessResult {
        let process = Process(
            arguments: arguments,
            environmentBlock: environmentBlock,
            outputRedirection: .collect,
            loggingHandler: loggingHandler
        )
        try process.launch()
        return try await process.waitUntilExit()
    }

    @_disfavoredOverload
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    @available(*, deprecated, renamed: "popen(arguments:environmentBlock:loggingHandler:)")
    static public func popen(
        arguments: [String],
        environment: [String:String] = ProcessEnv.vars,
        loggingHandler: LoggingHandler? = .none
    ) async throws -> ProcessResult {
        try await popen(arguments: arguments, environmentBlock: .init(environment), loggingHandler: loggingHandler)
    }

    /// Execute a subprocess and returns the result when it finishes execution
    ///
    /// - Parameters:
    ///   - args: The arguments for the subprocess.
    ///   - environment: The environment to pass to subprocess. By default the current process environment
    ///     will be inherited.
    ///   - loggingHandler: Handler for logging messages
    static public func popen(
        args: String...,
        environmentBlock: ProcessEnvironmentBlock = ProcessEnv.block,
        loggingHandler: LoggingHandler? = .none
    ) async throws -> ProcessResult {
        try await popen(arguments: args, environmentBlock: environmentBlock, loggingHandler: loggingHandler)
    }

    @_disfavoredOverload
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    @available(*, deprecated, renamed: "popen(args:environmentBlock:loggingHandler:)")
    static public func popen(
        args: String...,
        environment: [String: String] = ProcessEnv.vars,
        loggingHandler: LoggingHandler? = .none
    ) async throws -> ProcessResult {
        try await popen(arguments: args, environmentBlock: .init(environment), loggingHandler: loggingHandler)
    }

    /// Execute a subprocess and get its (UTF-8) output if it has a non zero exit.
    ///
    /// - Parameters:
    ///   - arguments: The arguments for the subprocess.
    ///   - environment: The environment to pass to subprocess. By default the current process environment
    ///     will be inherited.
    ///   - loggingHandler: Handler for logging messages
    /// - Returns: The process output (stdout + stderr).
    @discardableResult
    static public func checkNonZeroExit(
        arguments: [String],
        environmentBlock: ProcessEnvironmentBlock = ProcessEnv.block,
        loggingHandler: LoggingHandler? = .none
    ) async throws -> String {
        let result = try await popen(arguments: arguments, environmentBlock: environmentBlock, loggingHandler: loggingHandler)
        // Throw if there was a non zero termination.
        guard result.exitStatus == .terminated(code: 0) else {
            throw ProcessResult.Error.nonZeroExit(result)
        }
        return try result.utf8Output()
    }

    @_disfavoredOverload
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    @available(*, deprecated, renamed: "checkNonZeroExit(arguments:environmentBlock:loggingHandler:)")
    @discardableResult
    static public func checkNonZeroExit(
        arguments: [String],
        environment: [String: String] = ProcessEnv.vars,
        loggingHandler: LoggingHandler? = .none
    ) async throws -> String {
        try await checkNonZeroExit(arguments: arguments, environmentBlock: .init(environment), loggingHandler: loggingHandler)
    }

    /// Execute a subprocess and get its (UTF-8) output if it has a non zero exit.
    ///
    /// - Parameters:
    ///   - args: The arguments for the subprocess.
    ///   - environment: The environment to pass to subprocess. By default the current process environment
    ///     will be inherited.
    ///   - loggingHandler: Handler for logging messages
    /// - Returns: The process output (stdout + stderr).
    @discardableResult
    static public func checkNonZeroExit(
        args: String...,
        environmentBlock: ProcessEnvironmentBlock = ProcessEnv.block,
        loggingHandler: LoggingHandler? = .none
    ) async throws -> String {
        try await checkNonZeroExit(arguments: args, environmentBlock: environmentBlock, loggingHandler: loggingHandler)
    }

    @_disfavoredOverload
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    @available(*, deprecated, renamed: "checkNonZeroExit(args:environmentBlock:loggingHandler:)")
    @discardableResult
    static public func checkNonZeroExit(
        args: String...,
        environment: [String: String] = ProcessEnv.vars,
        loggingHandler: LoggingHandler? = .none
    ) async throws -> String {
        try await checkNonZeroExit(arguments: args, environmentBlock: .init(environment), loggingHandler: loggingHandler)
    }
}

extension Process {
    /// Execute a subprocess and calls completion block when it finishes execution
    ///
    /// - Parameters:
    ///   - arguments: The arguments for the subprocess.
    ///   - environment: The environment to pass to subprocess. By default the current process environment
    ///     will be inherited.
    ///   - loggingHandler: Handler for logging messages
    ///   - queue: Queue to use for callbacks
    ///   - completion: A completion handler to return the process result
//    #if compiler(>=5.8)
//    @available(*, noasync)
//    #endif
    static public func popen(
        arguments: [String],
        environmentBlock: ProcessEnvironmentBlock = ProcessEnv.block,
        loggingHandler: LoggingHandler? = .none,
        queue: DispatchQueue? = nil,
        completion: @escaping (Result<ProcessResult, Swift.Error>) -> Void
    ) {
        let completionQueue = queue ?? Self.sharedCompletionQueue

        do {
            let process = Process(
                arguments: arguments,
                environmentBlock: environmentBlock,
                outputRedirection: .collect,
                loggingHandler: loggingHandler
            )
            process.completionQueue = completionQueue
            try process.launch()
            process.waitUntilExit(completion)
        } catch {
            completionQueue.async {
                completion(.failure(error))
            }
        }
    }

    @_disfavoredOverload
    @available(*, deprecated, renamed: "popen(arguments:environmentBlock:loggingHandler:queue:completion:)")
    static public func popen(
        arguments: [String],
        environment: [String:String] = ProcessEnv.vars,
        loggingHandler: LoggingHandler? = .none,
        queue: DispatchQueue? = nil,
        completion: @escaping (Result<ProcessResult, Swift.Error>) -> Void
    ) {
        popen(
            arguments: arguments,
            environmentBlock: .init(environment),
            loggingHandler: loggingHandler,
            queue: queue,
            completion: completion
        )
    }

    /// Execute a subprocess and block until it finishes execution
    ///
    /// - Parameters:
    ///   - arguments: The arguments for the subprocess.
    ///   - environment: The environment to pass to subprocess. By default the current process environment
    ///     will be inherited.
    ///   - loggingHandler: Handler for logging messages
    /// - Returns: The process result.
//    #if compiler(>=5.8)
//    @available(*, noasync)
//    #endif
    @discardableResult
    static public func popen(
        arguments: [String],
        environmentBlock: ProcessEnvironmentBlock = ProcessEnv.block,
        loggingHandler: LoggingHandler? = .none
    ) throws -> ProcessResult {
        let process = Process(
            arguments: arguments,
            environmentBlock: environmentBlock,
            outputRedirection: .collect,
            loggingHandler: loggingHandler
        )
        try process.launch()
        return try process.waitUntilExit()
    }

    @_disfavoredOverload
    @available(*, deprecated, renamed: "popen(arguments:environmentBlock:loggingHandler:)")
    @discardableResult
    static public func popen(
        arguments: [String],
        environment: [String:String] = ProcessEnv.vars,
        loggingHandler: LoggingHandler? = .none
    ) throws -> ProcessResult {
        try popen(arguments: arguments, environmentBlock: .init(environment), loggingHandler: loggingHandler)
    }

    /// Execute a subprocess and block until it finishes execution
    ///
    /// - Parameters:
    ///   - args: The arguments for the subprocess.
    ///   - environment: The environment to pass to subprocess. By default the current process environment
    ///     will be inherited.
    ///   - loggingHandler: Handler for logging messages
    /// - Returns: The process result.
//    #if compiler(>=5.8)
//    @available(*, noasync)
//    #endif
    @discardableResult
    static public func popen(
        args: String...,
        environmentBlock: ProcessEnvironmentBlock = ProcessEnv.block,
        loggingHandler: LoggingHandler? = .none
    ) throws -> ProcessResult {
        return try Process.popen(arguments: args, environmentBlock: environmentBlock, loggingHandler: loggingHandler)
    }

    @_disfavoredOverload
    @available(*, deprecated, renamed: "popen(args:environmentBlock:loggingHandler:)")
    @discardableResult
    static public func popen(
        args: String...,
        environment: [String:String] = ProcessEnv.vars,
        loggingHandler: LoggingHandler? = .none
    ) throws -> ProcessResult {
        return try Process.popen(arguments: args, environmentBlock: .init(environment), loggingHandler: loggingHandler)
    }

    /// Execute a subprocess and get its (UTF-8) output if it has a non zero exit.
    ///
    /// - Parameters:
    ///   - arguments: The arguments for the subprocess.
    ///   - environment: The environment to pass to subprocess. By default the current process environment
    ///     will be inherited.
    ///   - loggingHandler: Handler for logging messages
    /// - Returns: The process output (stdout + stderr).
//    #if compiler(>=5.8)
//    @available(*, noasync)
//    #endif
    @discardableResult
    static public func checkNonZeroExit(
        arguments: [String],
        environmentBlock: ProcessEnvironmentBlock = ProcessEnv.block,
        loggingHandler: LoggingHandler? = .none
    ) throws -> String {
        let process = Process(
            arguments: arguments,
            environmentBlock: environmentBlock,
            outputRedirection: .collect,
            loggingHandler: loggingHandler
        )
        try process.launch()
        let result = try process.waitUntilExit()
        // Throw if there was a non zero termination.
        guard result.exitStatus == .terminated(code: 0) else {
            throw ProcessResult.Error.nonZeroExit(result)
        }
        return try result.utf8Output()
    }

    @_disfavoredOverload
    @available(*, deprecated, renamed: "checkNonZeroExit(arguments:environmentBlock:loggingHandler:)")
    @discardableResult
    static public func checkNonZeroExit(
        arguments: [String],
        environment: [String:String] = ProcessEnv.vars,
        loggingHandler: LoggingHandler? = .none
    ) throws -> String {
        try checkNonZeroExit(arguments: arguments, environmentBlock: .init(environment), loggingHandler: loggingHandler)
    }

    /// Execute a subprocess and get its (UTF-8) output if it has a non zero exit.
    ///
    /// - Parameters:
    ///   - arguments: The arguments for the subprocess.
    ///   - environment: The environment to pass to subprocess. By default the current process environment
    ///     will be inherited.
    ///   - loggingHandler: Handler for logging messages
    /// - Returns: The process output (stdout + stderr).
//    #if compiler(>=5.8)
//    @available(*, noasync)
//    #endif
    @discardableResult
    static public func checkNonZeroExit(
        args: String...,
        environmentBlock: ProcessEnvironmentBlock = ProcessEnv.block,
        loggingHandler: LoggingHandler? = .none
    ) throws -> String {
        return try checkNonZeroExit(arguments: args, environmentBlock: environmentBlock, loggingHandler: loggingHandler)
    }

    @_disfavoredOverload
    @available(*, deprecated, renamed: "checkNonZeroExit(args:environmentBlock:loggingHandler:)")
    @discardableResult
    static public func checkNonZeroExit(
        args: String...,
        environment: [String:String] = ProcessEnv.vars,
        loggingHandler: LoggingHandler? = .none
    ) throws -> String {
        try checkNonZeroExit(arguments: args, environmentBlock: .init(environment), loggingHandler: loggingHandler)
    }
}

extension Process: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    public static func == (lhs: Process, rhs: Process) -> Bool {
        ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

// MARK: - Private helpers

#if !os(Windows)
#if canImport(Darwin)
private typealias swiftpm_posix_spawn_file_actions_t = posix_spawn_file_actions_t?
#else
private typealias swiftpm_posix_spawn_file_actions_t = posix_spawn_file_actions_t
#endif

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

/// Open the given pipe.
private func open(pipe: inout [Int32]) throws {
    let rv = TSCLibc.pipe(&pipe)
    guard rv == 0 else {
        throw SystemError.pipe(rv)
    }
}

/// Close the given fd.
private func close(fd: Int32) throws {
    func innerClose(_ fd: inout Int32) throws {
        let rv = TSCLibc.close(fd)
        guard rv == 0 else {
            throw SystemError.close(rv)
        }
    }
    var innerFd = fd
    try innerClose(&innerFd)
}

extension Process.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .missingExecutableProgram(let program):
            return "could not find executable for '\(program)'"
        case .workingDirectoryNotSupported:
            return "workingDirectory is not supported in this platform"
        case .stdinUnavailable:
            return "could not open stdin on this platform"
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
        case .systemError(let arguments, let underlyingError):
            return "error while executing `\(arguments.joined(separator: " "))`: \(underlyingError)"
        case .illegalUTF8Sequence:
            return "illegal UTF8 sequence output"
        case .nonZeroExit(let result):
            let stream = BufferedOutputByteStream()
            switch result.exitStatus {
            case .terminated(let code):
                stream.send("terminated(\(code)): ")
#if os(Windows)
            case .abnormal(let exception):
                stream.send("abnormal(\(exception)): ")
#else
            case .signalled(let signal):
                stream.send("signalled(\(signal)): ")
#endif
            }

            // Strip sandbox information from arguments to keep things pretty.
            var args = result.arguments
            // This seems a little fragile.
            if args.first == "sandbox-exec", args.count > 3 {
                args = args.suffix(from: 3).map({$0})
            }
            stream.send(args.map({ $0.spm_shellEscaped() }).joined(separator: " "))

            // Include the output, if present.
            if let output = try? result.utf8Output() + result.utf8stderrOutput() {
                // We indent the output to keep it visually separated from everything else.
                let indentation = "    "
                stream.send(" output:\n").send(indentation).send(output.replacingOccurrences(of: "\n", with: "\n" + indentation))
                if !output.hasSuffix("\n") {
                    stream.send("\n")
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
}
#endif


extension Process {
    @available(*, deprecated)
    fileprivate static func logToStdout(_ message: String) {
        stdoutStream.send(message).send("\n")
        stdoutStream.flush()
    }
}
