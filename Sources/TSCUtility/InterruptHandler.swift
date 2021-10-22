/*
 This source file is part of the Swift.org open source project

 Copyright 2016 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import TSCLibc
import TSCBasic

/// This class can be used by command line tools to install a handler which
/// should be called when a interrupt signal is delivered to the process.
@available(*, deprecated, message: "use DispatchSource instead")
public final class InterruptHandler {
    /// Interrupt signal handling global variables
    private static var wasInterrupted = false
    private static var wasInterruptedLock = Lock()
    #if os(Windows)
    private static var signalWatchingPipe: [HANDLE] = [INVALID_HANDLE_VALUE, INVALID_HANDLE_VALUE]
    #else
    private static var signalWatchingPipe: [Int32] = [0, 0]
    private static var oldAction = sigaction()
    #endif

    /// The thread which waits to be notified when a signal is received.
    let thread: Thread
  #if os(Windows)
    let signalHandler: @convention(c)(UInt32) -> WindowsBool
  #else
    let signalHandler: @convention(c)(Int32) -> Void
  #endif

    /// Start watching for interrupt signal and call the handler whenever the signal is received.
    public init(_ handler: @escaping () -> Void) throws {
        // Swift reserves the right to lazily-initialize globals & statics
        // force initialize the statics so they as signal-safe
        _ = Self.wasInterrupted
        _ = Self.wasInterruptedLock
        _ = Self.signalWatchingPipe
#if !os(Windows)
        _ = Self.oldAction
#endif

        // Create a signal handler.
        self.signalHandler = { _ in
            // Turn on the interrupt bool.
            InterruptHandler.wasInterruptedLock.withLock {
                InterruptHandler.wasInterrupted = true
            }
            // Write on pipe to notify the watching thread.
            var byte: UInt8 = 0
          #if os(Windows)
            var bytesWritten: DWORD = 0
            WriteFile(InterruptHandler.signalWatchingPipe[1], &byte, 1, &bytesWritten, nil)
            return true
          #else
            write(InterruptHandler.signalWatchingPipe[1], &byte, 1)
          #endif
        }
      #if os(Windows)
        SetConsoleCtrlHandler(signalHandler, true)

        var readPipe: HANDLE?
        var writePipe: HANDLE?
        let rv = CreatePipe(&readPipe, &writePipe, nil, 1)
        Self.signalWatchingPipe = [readPipe!, writePipe!]
        guard rv else {
            throw SystemError.pipe(Int32(GetLastError()))
        }
      #else
        var action = sigaction()
      #if canImport(Darwin) || os(OpenBSD)
        action.__sigaction_u.__sa_handler = self.signalHandler
      #elseif os(Android)
        action.sa_handler = self.signalHandler
      #else
        action.__sigaction_handler = unsafeBitCast(
            self.signalHandler,
            to: sigaction.__Unnamed_union___sigaction_handler.self)
      #endif
        // Install the new handler.
        sigaction(SIGINT, &action, &Self.oldAction)
        // Create pipe.
        let rv = TSCLibc.pipe(&Self.signalWatchingPipe)
        guard rv == 0 else {
            throw SystemError.pipe(rv)
        }
      #endif

        // This thread waits to be notified via pipe. If something is read from pipe, check the interrupt bool
        // and send termination signal to all spawned processes in the process group.
        thread = Thread {
            while true {
                var buf: Int8 = 0
              #if os(Windows)
                var n: DWORD = 0
                ReadFile(Self.signalWatchingPipe[1], &buf, 1, &n, nil)
              #else
                let n = read(Self.signalWatchingPipe[0], &buf, 1)
              #endif
                // Pipe closed, nothing to do.
                if n == 0 { break }
                // Read the value of wasInterrupted and set it to false.
                let wasInt = Self.wasInterruptedLock.withLock { () -> Bool in
                    let oldValue = Self.wasInterrupted
                    Self.wasInterrupted = false
                    return oldValue
                }
                // Terminate all processes if was interrupted.
                if wasInt {
                    handler()
                }
            }
          #if os(Windows)
            CloseHandle(Self.signalWatchingPipe[0])
          #else
            close(Self.signalWatchingPipe[0])
          #endif
        }
        thread.start()
    }

    deinit {
      #if os(Windows)
        SetConsoleCtrlHandler(self.signalHandler, false)
        CloseHandle(Self.signalWatchingPipe[1])
      #else
        // Restore the old action and close the write end of pipe.
        sigaction(SIGINT, &Self.oldAction, nil)
        close(Self.signalWatchingPipe[1])
      #endif
        thread.join()
    }
}
