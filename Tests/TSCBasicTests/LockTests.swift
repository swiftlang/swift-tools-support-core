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

class LockTests: XCTestCase {
    @available(*, deprecated)
    func testBasics() {
        // FIXME: Make this a more interesting test once we have concurrency primitives.
        let lock = TSCBasic.Lock()
        var count = 0
        let N = 100
        for _ in 0..<N {
            lock.withLock {
                count += 1
            }
        }
        XCTAssertEqual(count, N)
    }

    func testFileLock() throws {
        // Shared resource file.
        try withTemporaryFile { sharedResource in
            // Directory where lock file should be created.
            try withTemporaryDirectory(removeTreeOnDeinit: true) { tempDirPath in
                // Run the same executable multiple times and
                // we can expect the final result to be sum of the
                // contents we write in the shared file.
                let N = 10
                let threads = (1...N).map { idx in
                    return Thread {
                        let lock = FileLock(at: tempDirPath.appending(component: "TestLock"))
                        try! lock.withLock {
                            // Get thr current contents of the file if any.
                            let currentData: Int
                            if localFileSystem.exists(sharedResource.path) {
                                currentData = Int(try localFileSystem.readFileContents(sharedResource.path).description) ?? 0
                            } else {
                                currentData = 0
                            }
                            // Sum and write back to file.
                            try localFileSystem.writeFileContents(sharedResource.path, bytes: ByteString(encodingAsUTF8: String(currentData + idx)))
                        }
                    }
                }
                threads.forEach { $0.start() }
                threads.forEach { $0.join() }

                XCTAssertEqual(try localFileSystem.readFileContents(sharedResource.path).description, String((N * (N + 1) / 2 )))
            }
        }
    }

    func testReadWriteFileLock() throws {
        try withTemporaryDirectory { tempDir in
            let fileA = tempDir.appending(component: "fileA")
            let fileB = tempDir.appending(component: "fileB")

            // write initial value, since reader may start before writers and files would not exist
            try localFileSystem.writeFileContents(fileA, bytes: "0")
            try localFileSystem.writeFileContents(fileB, bytes: "0")

            let writerThreads = (0..<100).map { _ in
                return Thread {
                    let lock = FileLock(at: tempDir.appending(component: "foo"))
                    try! lock.withLock(type: .exclusive) {
                        // Get the current contents of the file if any.
                        let valueA = Int(try localFileSystem.readFileContents(fileA).description)!
                        // Sum and write back to file.
                        try localFileSystem.writeFileContents(fileA, bytes: ByteString(encodingAsUTF8: String(valueA + 1)))

                        Thread.yield()

                        // Get the current contents of the file if any.
                        let valueB = Int(try localFileSystem.readFileContents(fileB).description)!
                        // Sum and write back to file.
                        try localFileSystem.writeFileContents(fileB, bytes: ByteString(encodingAsUTF8: String(valueB + 1)))
                    }
                }
            }

            let readerThreads = (0..<20).map { _ in
                return Thread {
                    let lock = FileLock(at: tempDir.appending(component: "foo"))
                    try! lock.withLock(type: .shared) {
                        try XCTAssertEqual(localFileSystem.readFileContents(fileA), localFileSystem.readFileContents(fileB))

                        Thread.yield()

                        try XCTAssertEqual(localFileSystem.readFileContents(fileA), localFileSystem.readFileContents(fileB))
                    }
                }
            }

            writerThreads.forEach { $0.start() }
            readerThreads.forEach { $0.start() }
            writerThreads.forEach { $0.join() }
            readerThreads.forEach { $0.join() }

            try XCTAssertEqual(localFileSystem.readFileContents(fileA), "100")
            try XCTAssertEqual(localFileSystem.readFileContents(fileB), "100")
        }
    }
    
    func testFileLockLocation() throws {
        do {
            let fileName = UUID().uuidString
            let fileToLock = localFileSystem.homeDirectory.appending(component: fileName)
            try localFileSystem.withLock(on: fileToLock, type: .exclusive) {}
            
            // lock file expected at temp when lockFilesDirectory set to nil
            // which is the case when going through localFileSystem
            let lockFile = try localFileSystem.getDirectoryContents(localFileSystem.tempDirectory)
                .first(where: { $0.contains(fileName) })
            XCTAssertNotNil(lockFile, "expected lock file at \(localFileSystem.tempDirectory)")
        }
        
        do {
            let fileName = UUID().uuidString
            let fileToLock = localFileSystem.homeDirectory.appending(component: fileName)
            try FileLock.withLock(fileToLock: fileToLock, lockFilesDirectory: nil, body: {})
            
            // lock file expected at temp when lockFilesDirectory set to nil
            let lockFile = try localFileSystem.getDirectoryContents(localFileSystem.tempDirectory)
                .first(where: { $0.contains(fileName) })
            XCTAssertNotNil(lockFile, "expected lock file at \(localFileSystem.tempDirectory)")
        }
        
        do {
            try withTemporaryDirectory { tempDir in
                let fileName = UUID().uuidString
                let fileToLock = localFileSystem.homeDirectory.appending(component: fileName)
                try FileLock.withLock(fileToLock: fileToLock, lockFilesDirectory: tempDir, body: {})
                
                // lock file expected at specified directory when lockFilesDirectory is set to a valid directory
                let lockFile = try localFileSystem.getDirectoryContents(tempDir)
                    .first(where: { $0.contains(fileName) })
                XCTAssertNotNil(lockFile, "expected lock file at \(tempDir)")
            }
        }
        
        do {
            let fileName = UUID().uuidString
            let fileToLock = localFileSystem.homeDirectory.appending(component: fileName)
            let lockFilesDirectory = localFileSystem.homeDirectory.appending(component: UUID().uuidString)
            XCTAssertThrows(FileSystemError(.noEntry, lockFilesDirectory)) {
                try FileLock.withLock(fileToLock: fileToLock, lockFilesDirectory: lockFilesDirectory, body: {})
            }
        }
        
        do {
            let fileName = UUID().uuidString
            let fileToLock = localFileSystem.homeDirectory.appending(component: fileName)
            let lockFilesDirectory = localFileSystem.homeDirectory.appending(component: UUID().uuidString)
            try localFileSystem.writeFileContents(lockFilesDirectory, bytes: [])
            XCTAssertThrows(FileSystemError(.notDirectory, lockFilesDirectory)) {
                try FileLock.withLock(fileToLock: fileToLock, lockFilesDirectory: lockFilesDirectory, body: {})
            }
        }
    }
}
