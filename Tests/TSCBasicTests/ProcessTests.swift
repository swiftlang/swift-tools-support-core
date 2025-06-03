/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import TSCTestSupport
import XCTest

@_implementationOnly import TSCclibc
import TSCLibc
import TSCBasic

typealias ProcessID = TSCBasic.Process.ProcessID
typealias Process = TSCBasic.Process

class ProcessTests: XCTestCase {
    func testBasics() throws {
        do {
            let process = Process(args: "echo", "hello")
            try process.launch()
            let result = try process.waitUntilExit()
            XCTAssertEqual(try result.utf8Output(), "hello\n")
            XCTAssertEqual(result.exitStatus, .terminated(code: 0))
            XCTAssertEqual(result.arguments, process.arguments)
        }

        do {
            let process = Process(scriptName: "exit4")
            try process.launch()
            let result = try process.waitUntilExit()
            XCTAssertEqual(result.exitStatus, .terminated(code: 4))
        }
    }

    func testPopen() throws {
        #if os(Windows)
        let echo = "echo.exe"
        #else
        let echo = "echo"
        #endif
        // Test basic echo.
        XCTAssertEqual(try Process.popen(arguments: [echo, "hello"]).utf8Output(), "hello\n")

        // Test buffer larger than that allocated.
        try withTemporaryFile { file in
            let count = 10_000
            let stream = BufferedOutputByteStream()
            stream.send(Format.asRepeating(string: "a", count: count))
            try localFileSystem.writeFileContents(file.path, bytes: stream.bytes)
            #if os(Windows)
            let cat = "cat.exe"
            #else
            let cat = "cat"
            #endif
            let outputCount = try Process.popen(args: cat, file.path.pathString).utf8Output().count
            XCTAssert(outputCount == count)
        }
    }

    func testPopenLegacyAsync() throws {
        #if os(Windows)
        let args = ["where.exe", "where"]
        let answer = "C:\\Windows\\System32\\where.exe"
        #else
        let args = ["whoami"]
        let answer = NSUserName()
        #endif
        var popenResult: Result<ProcessResult, Error>?
        let group = DispatchGroup()
        group.enter()
        Process.popen(arguments: args) { result in
            popenResult = result
            group.leave()
        }
        group.wait()
        switch popenResult {
        case .success(let processResult):
            let output = try processResult.utf8Output()
            XCTAssertTrue(output.hasPrefix(answer))
        case .failure(let error):
            XCTFail("error = \(error)")
        case nil:
            XCTFail()
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func testPopenAsync() async throws {
        #if os(Windows)
        let args = ["where.exe", "where"]
        let answer = "C:\\Windows\\System32\\where.exe"
        #else
        let args = ["whoami"]
        let answer = NSUserName()
        #endif
        let processResult: ProcessResult
        do {
            processResult = try await Process.popen(arguments: args)
        } catch let error {
            XCTFail("error = \(error)")
            return
        }
        let output = try processResult.utf8Output()
        XCTAssertTrue(output.hasPrefix(answer))
    }

    func testCheckNonZeroExit() throws {
        do {
            let output = try Process.checkNonZeroExit(args: "echo", "hello")
            XCTAssertEqual(output, "hello\n")
        }

        do {
            let output = try Process.checkNonZeroExit(scriptName: "exit4")
            XCTFail("Unexpected success \(output)")
        } catch ProcessResult.Error.nonZeroExit(let result) {
            XCTAssertEqual(result.exitStatus, .terminated(code: 4))
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func testCheckNonZeroExitAsync() async throws {
        do {
            let output = try await Process.checkNonZeroExit(args: "echo", "hello")
            XCTAssertEqual(output, "hello\n")
        }

        do {
            let output = try await Process.checkNonZeroExit(scriptName: "exit4")
            XCTFail("Unexpected success \(output)")
        } catch ProcessResult.Error.nonZeroExit(let result) {
            XCTAssertEqual(result.exitStatus, .terminated(code: 4))
        }
    }

    func testFindExecutable() throws {
        try testWithTemporaryDirectory { tmpdir in
            // This process should always work.
            XCTAssertTrue(Process.findExecutable("ls") != nil)

            XCTAssertEqual(Process.findExecutable("nonExistantProgram"), nil)
            XCTAssertEqual(Process.findExecutable(""), nil)

            // Create a local nonexecutable file to test.
            let tempExecutable = tmpdir.appending(component: "nonExecutableProgram")
            try localFileSystem.writeFileContents(tempExecutable, bytes: """
                #!/bin/sh
                exit

                """)

            try withCustomEnv(["PATH": tmpdir.pathString]) {
                XCTAssertEqual(Process.findExecutable("nonExecutableProgram"), nil)
            }
        }
    }

    func testNonExecutableLaunch() throws {
        try testWithTemporaryDirectory { tmpdir in
            // Create a local nonexecutable file to test.
            let tempExecutable = tmpdir.appending(component: "nonExecutableProgram")
            try localFileSystem.writeFileContents(tempExecutable, bytes: """
                #!/bin/sh
                exit

                """)

            try withCustomEnv(["PATH": tmpdir.pathString]) {
                do {
                    let process = Process(args: "nonExecutableProgram")
                    try process.launch()
                    XCTFail("Should have failed to validate nonExecutableProgram")
                } catch Process.Error.missingExecutableProgram (let program){
                    XCTAssert(program == "nonExecutableProgram")
                }
            }
        }
    }

  #if !os(Windows) // Signals are not supported in Windows
    @available(*, deprecated)
    func testSignals() throws {
        let processes  = ProcessSet()
        let group = DispatchGroup()

        DispatchQueue.global().async(group: group) {
            do {
                // Test sigint terminates the script.
                try testWithTemporaryDirectory { tmpdir in
                    let file = tmpdir.appending(component: "pidfile")
                    let waitFile = tmpdir.appending(component: "waitFile")
                    let process = Process(scriptName: "print-pid", arguments: [file.pathString, waitFile.pathString])
                    try processes.add(process)
                    try process.launch()
                    guard waitForFile(waitFile) else {
                        return XCTFail("Couldn't launch the process")
                    }
                    // Ensure process has started running.
                    guard try Process.running(process.processID) else {
                       return XCTFail("Couldn't launch the process")
                    }
                    process.signal(SIGINT)
                    try process.waitUntilExit()
                    // Ensure the process's pid was written.
                    let contents = try localFileSystem.readFileContents(file).description
                    XCTAssertEqual("\(process.processID)", contents)
                    XCTAssertFalse(try Process.running(process.processID))
                }
            } catch {
                XCTFail("\(error)")
            }
        }

        // Test SIGKILL terminates the subprocess and any of its subprocess.
        DispatchQueue.global().async(group: group) {
            do {
                try testWithTemporaryDirectory { tmpdir in
                    let file = tmpdir.appending(component: "pidfile")
                    let waitFile = tmpdir.appending(component: "waitFile")
                    let process = Process(scriptName: "subprocess", arguments: [file.pathString, waitFile.pathString])
                    try processes.add(process)
                    try process.launch()
                    guard waitForFile(waitFile) else {
                        return XCTFail("Couldn't launch the process")
                    }
                    // Ensure process has started running.
                    guard try Process.running(process.processID) else {
                        return XCTFail("Couldn't launch the process")
                    }
                    process.signal(SIGKILL)
                    let result = try process.waitUntilExit()
                    XCTAssertEqual(result.exitStatus, .signalled(signal: SIGKILL))
                    let json = try JSON(bytes: localFileSystem.readFileContents(file))
                    guard case let .dictionary(dict) = json,
                          case let .int(parent)? = dict["parent"],
                          case let .int(child)? = dict["child"] else {
                        return XCTFail("Couldn't launch the process")
                    }
                    XCTAssertEqual(process.processID, ProcessID(parent))
                    // We should have killed the process and any subprocess spawned by it.
                    XCTAssertFalse(try Process.running(ProcessID(parent)))
                    // FIXME: The child process becomes defunct when executing the tests using docker directly without entering the bash.
                    XCTAssertFalse(try Process.running(ProcessID(child), orDefunct: true))
                }
            } catch {
                XCTFail("\(error)")
            }
        }

        if case .timedOut = group.wait(timeout: .now() + 10) {
            XCTFail("timeout waiting for signals to be processed")
        }

        // rdar://74356445: make sure the processes are terminated as they *sometimes* cause xctest to hang
        processes.terminate()
    }
  #endif

    func testThreadSafetyOnWaitUntilExit() throws {
        let process = Process(args: "echo", "hello")
        try process.launch()

        var result1: String = ""
        var result2: String = ""

        let t1 = Thread {
            result1 = try! process.waitUntilExit().utf8Output()
        }

        let t2 = Thread {
            result2 = try! process.waitUntilExit().utf8Output()
        }

        t1.start()
        t2.start()
        t1.join()
        t2.join()

        XCTAssertEqual(result1, "hello\n")
        XCTAssertEqual(result2, "hello\n")
    }

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    func testThreadSafetyOnWaitUntilExitAsync() async throws {
        let process = Process(args: "echo", "hello")
        try process.launch()

        let t1 = Task {
            try await process.waitUntilExit().utf8Output()
        }

        let t2 = Task {
            try await process.waitUntilExit().utf8Output()
        }

        let result1 = try await t1.value
        let result2 = try await t2.value

        XCTAssertEqual(result1, "hello\n")
        XCTAssertEqual(result2, "hello\n")
    }

    func testStdin() throws {
        var stdout = [UInt8]()
        let process = Process(scriptName: "in-to-out", outputRedirection: .stream(stdout: { stdoutBytes in
            stdout += stdoutBytes
        }, stderr: { _ in }))
        let stdinStream = try process.launch()

        stdinStream.write("hello\n")
        stdinStream.flush()

        try stdinStream.close()

        try process.waitUntilExit()

        XCTAssertEqual(String(decoding: stdout, as: UTF8.self), "hello\n")
    }

    func testStdoutStdErr() throws {
        // A simple script to check that stdout and stderr are captured separatly.
        do {
            let result = try Process.popen(scriptName: "simple-stdout-stderr")
            XCTAssertEqual(try result.utf8Output(), "simple output\n")
            XCTAssertEqual(try result.utf8stderrOutput(), "simple error\n")
        }

        // A long stdout and stderr output.
        do {
            let result = try Process.popen(scriptName: "long-stdout-stderr")
            let count = 16 * 1024
            XCTAssertEqual(try result.utf8Output(), String(repeating: "1", count: count))
            XCTAssertEqual(try result.utf8stderrOutput(), String(repeating: "2", count: count))
        }

        // This script will block if the streams are not read.
        do {
            let result = try Process.popen(scriptName: "deadlock-if-blocking-io")
            let count = 16 * 1024
            XCTAssertEqual(try result.utf8Output(), String(repeating: "1", count: count))
            XCTAssertEqual(try result.utf8stderrOutput(), String(repeating: "2", count: count))
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func testStdoutStdErrAsync() async throws {
        // A simple script to check that stdout and stderr are captured separatly.
        do {
            let result = try await Process.popen(scriptName: "simple-stdout-stderr")
            XCTAssertEqual(try result.utf8Output(), "simple output\n")
            XCTAssertEqual(try result.utf8stderrOutput(), "simple error\n")
        }

        // A long stdout and stderr output.
        do {
            let result = try await Process.popen(scriptName: "long-stdout-stderr")
            let count = 16 * 1024
            XCTAssertEqual(try result.utf8Output(), String(repeating: "1", count: count))
            XCTAssertEqual(try result.utf8stderrOutput(), String(repeating: "2", count: count))
        }

        // This script will block if the streams are not read.
        do {
            let result = try await Process.popen(scriptName: "deadlock-if-blocking-io")
            let count = 16 * 1024
            XCTAssertEqual(try result.utf8Output(), String(repeating: "1", count: count))
            XCTAssertEqual(try result.utf8stderrOutput(), String(repeating: "2", count: count))
        }
    }

    func testStdoutStdErrRedirected() throws {
        // A simple script to check that stdout and stderr are captured in the same location.
        do {
            let process = Process(scriptName: "simple-stdout-stderr", outputRedirection: .collect(redirectStderr: true))
            try process.launch()
            let result = try process.waitUntilExit()
            XCTAssertEqual(try result.utf8Output(), "simple error\nsimple output\n")
            XCTAssertEqual(try result.utf8stderrOutput(), "")
        }

        // A long stdout and stderr output.
        do {
            let process = Process(scriptName: "long-stdout-stderr", outputRedirection: .collect(redirectStderr: true))
            try process.launch()
            let result = try process.waitUntilExit()

            let count = 16 * 1024
            XCTAssertEqual(try result.utf8Output(), String(repeating: "12", count: count))
            XCTAssertEqual(try result.utf8stderrOutput(), "")
        }
    }

    func testStdoutStdErrStreaming() throws {
        var stdout = [UInt8]()
        var stderr = [UInt8]()
        let process = Process(scriptName: "long-stdout-stderr", outputRedirection: .stream(stdout: { stdoutBytes in
            stdout += stdoutBytes
        }, stderr: { stderrBytes in
            stderr += stderrBytes
        }))
        try process.launch()
        try process.waitUntilExit()

        let count = 16 * 1024
        XCTAssertEqual(String(bytes: stdout, encoding: .utf8), String(repeating: "1", count: count))
        XCTAssertEqual(String(bytes: stderr, encoding: .utf8), String(repeating: "2", count: count))
    }

    func testStdoutStdErrStreamingRedirected() throws {
        var stdout = [UInt8]()
        var stderr = [UInt8]()
        let process = Process(scriptName: "long-stdout-stderr", outputRedirection: .stream(stdout: { stdoutBytes in
            stdout += stdoutBytes
        }, stderr: { stderrBytes in
            stderr += stderrBytes
        }, redirectStderr: true))
        try process.launch()
        try process.waitUntilExit()

        let count = 16 * 1024
        XCTAssertEqual(String(bytes: stdout, encoding: .utf8), String(repeating: "12", count: count))
        XCTAssertEqual(stderr, [])
    }

    func testWorkingDirectory() throws {
        guard #available(macOS 10.15, *) else {
            // Skip this test since it's not supported in this OS.
            return
        }

      #if os(Linux) || os(Android)
        guard SPM_posix_spawn_file_actions_addchdir_np_supported() else {
            // Skip this test since it's not supported in this OS.
            return
        }
      #endif

        try withTemporaryDirectory(removeTreeOnDeinit: true) { tempDirPath in
            let parentPath = tempDirPath.appending(component: "file")
            let childPath = tempDirPath.appending(component: "subdir").appending(component: "file")

            try localFileSystem.writeFileContents(parentPath, bytes: ByteString("parent"))
            try localFileSystem.createDirectory(childPath.parentDirectory, recursive: true)
            try localFileSystem.writeFileContents(childPath, bytes: ByteString("child"))

            do {
                let process = Process(arguments: ["cat", "file"], workingDirectory: tempDirPath)
                try process.launch()
                let result = try process.waitUntilExit()
                XCTAssertEqual(try result.utf8Output(), "parent")
            }

            do {
                let process = Process(arguments: ["cat", "file"], workingDirectory: childPath.parentDirectory)
                try process.launch()
                let result = try process.waitUntilExit()
                XCTAssertEqual(try result.utf8Output(), "child")
            }
        }
    }
}

fileprivate extension Process {
    private static func env() -> [String:String] {
        return ProcessEnv.vars
    }

    private static func script(_ name: String) -> String {
        return AbsolutePath(#file).parentDirectory.appending(components: "processInputs", name).pathString
    }

    convenience init(scriptName: String, arguments: [String] = [], outputRedirection: OutputRedirection = .collect) {
        self.init(arguments: [Self.script(scriptName)] + arguments, environment: Self.env(), outputRedirection: outputRedirection)
    }

    @available(*, noasync)
    static func checkNonZeroExit(
        scriptName: String,
        environment: [String: String] = ProcessEnv.vars,
        loggingHandler: LoggingHandler? = .none
    ) throws -> String {
        return try checkNonZeroExit(args: script(scriptName), environment: environment, loggingHandler: loggingHandler)
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    static func checkNonZeroExit(
        scriptName: String,
        environment: [String: String] = ProcessEnv.vars,
        loggingHandler: LoggingHandler? = .none
    ) async throws -> String {
        return try await checkNonZeroExit(args: script(scriptName), environment: environment, loggingHandler: loggingHandler)
    }

    @available(*, noasync)
    @discardableResult
    static func popen(
        scriptName: String,
        environment: [String: String] = ProcessEnv.vars,
        loggingHandler: LoggingHandler? = .none
    ) throws -> ProcessResult {
        return try popen(arguments: [script(scriptName)], environment: Self.env(), loggingHandler: loggingHandler)
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    @discardableResult
    static func popen(
        scriptName: String,
        environment: [String: String] = ProcessEnv.vars,
        loggingHandler: LoggingHandler? = .none
    ) async throws -> ProcessResult {
        return try await popen(arguments: [script(scriptName)], environment: Self.env(), loggingHandler: loggingHandler)
    }
}
