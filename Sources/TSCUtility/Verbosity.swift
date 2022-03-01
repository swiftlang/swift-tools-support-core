/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// verbose 2/2022
@available(*, deprecated)
public enum Verbosity: Int {
    case concise
    case verbose
    case debug

    public init(rawValue: Int) {
        switch rawValue {
        case Int.min...0:
            self = .concise
        case 1:
            self = .verbose
        default:
            self = .debug
        }
    }

    public var ccArgs: [String] {
        switch self {
        case .concise:
            return []
        case .verbose:
            // the first level of verbosity is passed to llbuild itself
            return []
        case .debug:
            return ["-v"]
        }
    }
}

// verbose 2/2022
@available(*, deprecated)
public var verbosity = Verbosity.concise
