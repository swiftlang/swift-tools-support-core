/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import XCTest

import TSCBasic
import TSCTestSupport
#if os(Windows)
import WinSDK
#endif

class ProcessEnvTests: XCTestCase {

    func testEnvVars() throws {
        let key = "SWIFTPM_TEST_FOO"
        XCTAssertEqual(ProcessEnv.vars[key], nil)
        try ProcessEnv.setVar(key, value: "BAR")
        XCTAssertEqual(ProcessEnv.vars[key], "BAR")
        try ProcessEnv.unsetVar(key)
        XCTAssertEqual(ProcessEnv.vars[key], nil)
    }

    func testChdir() throws {
        try testWithTemporaryDirectory { tmpdir in
            let path = try resolveSymlinks(tmpdir)
            try ProcessEnv.chdir(path)
            XCTAssertEqual(ProcessEnv.cwd, path)
        }
    }

    func testWithCustomEnv() throws {
        enum CustomEnvError: Swift.Error {
            case someError
        }

        let key = "XCTEST_TEST"
        let value = "TEST"
        XCTAssertNil(ProcessEnv.vars[key])
        try withCustomEnv([key: value]) {
            XCTAssertEqual(value, ProcessEnv.vars[key])
        }
        XCTAssertNil(ProcessEnv.vars[key])
        do {
            try withCustomEnv([key: value]) {
                XCTAssertEqual(value, ProcessEnv.vars[key])
                throw CustomEnvError.someError
            }
        } catch CustomEnvError.someError {
        } catch {
            XCTFail("Incorrect error thrown")
        }
        XCTAssertNil(ProcessEnv.vars[key])
    }

    func testWin32API() throws {
        #if os(Windows)
        let variable: String = "SWIFT_TOOLS_SUPPORT_CORE_VARIABLE"
        let value: String = "1"

        try variable.withCString(encodedAs: UTF16.self) { pwszVariable in
            try value.withCString(encodedAs: UTF16.self) { pwszValue in
                guard SetEnvironmentVariableW(pwszVariable, pwszValue) else {
                    throw XCTSkip("Failed to set environment variable")
                }
            }
        }

        // Ensure that libc does not see the variable.
        XCTAssertNil(getenv(variable))
        variable.withCString(encodedAs: UTF16.self) { pwszVariable in
            XCTAssertNil(_wgetenv(pwszVariable))
        }

        // Ensure that we can read the variable
        ProcessEnv.invalidateEnv()
        XCTAssertEqual(ProcessEnv.block[ProcessEnvironmentBlock.Key(variable)], value)

        // Ensure that we can read the variable using the Win32 API.
        variable.withCString(encodedAs: UTF16.self) { pwszVariable in
            let dwLength = GetEnvironmentVariableW(pwszVariable, nil, 0)
            withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwLength + 1)) {
                let dwLength = GetEnvironmentVariableW(pwszVariable, $0.baseAddress, dwLength + 1)
                XCTAssertEqual(dwLength, 1)
                XCTAssertEqual(String(decodingCString: $0.baseAddress!, as: UTF16.self), value)
            }
        }
        #else
        throw XCTSkip("Win32 API is only available on Windows")
        #endif

    }
}
