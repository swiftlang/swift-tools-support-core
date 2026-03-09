/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import TSCBasic
import TSCTestSupport
import XCTest

class PathWindowsRelativeTests: XCTestCase {

    #if os(Windows)
    func testRelativePathAcrossDifferentDrives() {
        // On Windows, you cannot express a path from one drive to another
        // using relative path components (.. and .). This test verifies that
        // the relative(to:) method handles this case without assertion failure.

        let pathOnCDrive = AbsolutePath(#"C:\Users\test"#)
        let baseOnDDrive = AbsolutePath(#"D:\"#)

        // This should not trigger an assertion failure.
        // The method will return a relative path that cannot properly reconstruct
        // the original path (since cross-drive relative paths are impossible),
        // but it should handle the case gracefully.
        let relative = pathOnCDrive.relative(to: baseOnDDrive)

        // The relative path should be non-empty
        XCTAssertFalse(relative.pathString.isEmpty)

        // Note: AbsolutePath(baseOnDDrive, relative) will NOT equal pathOnCDrive
        // because there's no valid relative path between different drives on Windows.
        // This is expected behavior for cross-drive paths.
    }

    func testRelativePathOnSameDrive() {
        // Verify that relative paths work correctly when on the same drive
        let path = AbsolutePath(#"C:\Users\test\Documents"#)
        let base = AbsolutePath(#"C:\Users"#)

        let relative = path.relative(to: base)

        // Should be able to reconstruct the original path
        XCTAssertEqual(AbsolutePath(base, relative), path)
        XCTAssertEqual(relative.pathString, #"test\Documents"#)
    }

    func testRelativePathWithParentTraversal() {
        // Test going up and down on the same drive
        let path = AbsolutePath(#"C:\Projects\MyApp"#)
        let base = AbsolutePath(#"C:\Users\test"#)

        let relative = path.relative(to: base)

        // Should be able to reconstruct the original path
        XCTAssertEqual(AbsolutePath(base, relative), path)
        // From C:\Users\test to C:\Projects\MyApp:
        // - Go up 2 levels (test -> Users -> C:)
        // - Then down to Projects\MyApp
        XCTAssertEqual(relative.pathString, #"..\..\Projects\MyApp"#)
    }

    func testCrossDriveVariants() {
        // Test various cross-drive scenarios
        let scenarios = [
            (AbsolutePath(#"C:\Users\test"#), AbsolutePath(#"D:\"#)),
            (AbsolutePath(#"D:\Data\files"#), AbsolutePath(#"C:\Windows"#)),
            (AbsolutePath(#"E:\Backup"#), AbsolutePath(#"C:\Users"#)),
        ]

        for (path, base) in scenarios {
            // Should not crash or trigger assertion
            let _ = path.relative(to: base)
        }
    }

    func testCrossDrivePreservesLeadingBackslash() {
        // When computing a relative path across different drives,
        // the leading backslash must be preserved to maintain drive-relative semantics.
        // C:\directory\file.txt -> \directory\file.txt (not directory\file.txt)
        // This distinction is important:
        // - \directory\file.txt is a drive-relative absolute path
        // - directory\file.txt is relative to the current working directory on that drive

        let pathOnCDrive = AbsolutePath(#"C:\Users\test\Documents\file.txt"#)
        let baseOnDDrive = AbsolutePath(#"D:\Projects"#)

        let relative = pathOnCDrive.relative(to: baseOnDDrive)

        // The relative path should start with a backslash to indicate drive-relative
        XCTAssertTrue(relative.pathString.hasPrefix("\\"),
                     "Cross-drive relative path should start with \\ to preserve drive-relative semantics, got: \(relative.pathString)")

        // Should contain the path components without the drive letter
        XCTAssertTrue(relative.pathString.contains("Users"),
                     "Path should contain directory components")
        XCTAssertTrue(relative.pathString.contains("test"),
                     "Path should contain directory components")

        // More specifically, it should be something like \Users\test\Documents\file.txt
        XCTAssertEqual(relative.pathString, #"\Users\test\Documents\file.txt"#)
    }
    #endif
}
