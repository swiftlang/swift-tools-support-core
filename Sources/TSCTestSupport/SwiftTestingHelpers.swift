/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing

import TSCBasic

public func expectFileExists(
    _ path: AbsolutePath,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    print("localFileSystem.isFile(path) ==> \(localFileSystem.isFile(path))")
    #expect(
        localFileSystem.isFile(path),
        "Expected file doesn't exist: \(path)",
        sourceLocation: sourceLocation
    )
}
public func expectDirectoryExists(
    _ path: AbsolutePath,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        localFileSystem.isDirectory(path),
        "Expected directory doesn't exist: \(path)",
        sourceLocation: sourceLocation
    )
}

public func expectNoDiagnostics(
    _ engine: DiagnosticsEngine,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let diagnostics = engine.diagnostics
    let diags = diagnostics.map({ "- " + $0.description }).joined(separator: "\n")
    #expect(
        diagnostics.isEmpty,
        "Found unexpected diagnostics: \n\(diags)",
        sourceLocation: sourceLocation
    )
}
