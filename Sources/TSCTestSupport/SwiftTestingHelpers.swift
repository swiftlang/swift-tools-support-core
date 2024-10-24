/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing

import TSCBasic

public func assertFileExists(_ path: AbsolutePath) {
    print("localFileSystem.isFile(path) ==> \(localFileSystem.isFile(path))")
    #expect(localFileSystem.isFile(path), "Expected file doesn't exist: \(path)")
}
public func assertDirectoryExists(_ path: AbsolutePath) {
    #expect(localFileSystem.isDirectory(path), "Expected directory doesn't exist: \(path)")
}

public func assertNoDiagnostics(_ engine: DiagnosticsEngine) {
    let diagnostics = engine.diagnostics
    let diags = diagnostics.map({ "- " + $0.description }).joined(separator: "\n")
    #expect(diagnostics.isEmpty, "Found unexpected diagnostics: \n\(diags)")
}
