/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import _Concurrency

import TSCUtility

final class SendableTests: XCTestCase {
#if compiler(>=5.5.2)
    func testByteContextIsSendable() {
        self.sendableBlackhole(Context())
    }

    // MARK: - Utilities
    private func sendableBlackhole<T: Sendable>(_ value: T) {}
#endif
}
