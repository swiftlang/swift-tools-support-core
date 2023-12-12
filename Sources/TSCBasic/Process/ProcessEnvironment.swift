/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import class Foundation.ProcessInfo

public struct ProcessEnvironment: Sendable {
    private(set) var storage = [String: String]()

    public private(set) subscript(_ key: String) -> String? {
        get {
            #if os(Windows)
            storage[key.lowercased()]
            #else
            storage[key]
            #endif
        }
        set {
            #if os(Windows)
            storage[key.lowercased()] = newValue
            #else
            storage[key] = newValue
            #endif
        }
    }

    /// `PATH` variable in the process's environment (`Path` under Windows).
    public var path: String? {
        self["PATH"]
    }

    public static var current: ProcessEnvironment {
        .init(ProcessInfo.processInfo.environment)
    }
}

extension ProcessEnvironment {
    public init(_ storage: [String : String]) {
        var result = ProcessEnvironment()
        for (key, value) in storage {
            result[key] = value
        }
        self = result
    }
}
