/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import Foundation

public struct Tracing {
    public enum EventType {
        case asyncBegin
        case asyncEnd
    }

    public struct Event {
        /// The category of the event.
        public let cat: String

        /// The name of the event.
        public let name: String

        /// The free form id of the event.
        public let id: String

        /// The phase of the event.
        public let ph: EventType

        /// The process id of the process where the event occured.
        public let pid: Int

        /// The thread id of the process where the event occured.
        public let tid: Int

        /// The timestamp of the event.
        public let ts: Int

        /// The start time of the process where the event occured.
        public let startTs: Int

        #if canImport(Darwin)
        public init(
            cat: String,
            name: String,
            id: String,
            ph: EventType,
            pid: Int = Int(getpid()),
            tid: Int = Int(pthread_mach_thread_np(pthread_self())),
            ts: Int = Int(DispatchTime.now().uptimeNanoseconds),
            startTs: Int = 0
        ) {
            self.cat = cat
            self.name = name
            self.id = id
            self.ph = ph
            self.pid = pid
            self.tid = tid
            self.ts = ts
            self.startTs = startTs
        }
        #elseif canImport(Glibc)
        public init(
            cat: String,
            name: String,
            id: String,
            ph: EventType,
            pid: Int = Int(getpid()),
            tid: Int = 1,
            ts: Int = Int(DispatchTime.now().uptimeNanoseconds),
            startTs: Int = 0
        ) {
            self.cat = cat
            self.name = name
            self.id = id
            self.ph = ph
            self.pid = pid
            self.tid = tid
            self.ts = ts
            self.startTs = startTs
        }
        #else
        public init(
            cat: String,
            name: String,
            id: String,
            ph: EventType,
            pid: Int = 1,
            tid: Int = 1,
            ts: Int = Int(DispatchTime.now().uptimeNanoseconds),
            startTs: Int = 0
        ) {
            self.cat = cat
            self.name = name
            self.id = id
            self.ph = ph
            self.pid = pid
            self.tid = tid
            self.ts = ts
            self.startTs = startTs
        }
        #endif
    }

    public struct Collection {
        public var events: [Event] = []
        public init(_ events: [Tracing.Event] = []) {
            self.events = events
        }
    }
}

extension Context {
    public static func withTracing(_ collection: Tracing.Collection) -> Context {
        return Context(dictionaryLiteral: (ObjectIdentifier(Tracing.Collection.self), collection as Any))
    }

    public mutating func enrichWithTracing(_ collection: Tracing.Collection) -> Context {
        self[ObjectIdentifier(Tracing.Collection.self)] = collection
        return self
    }

    var tracing: Tracing.Collection? {
        get {
            guard let collection = self[ObjectIdentifier(Tracing.Collection.self)] as? Tracing.Collection else {
                return nil
            }
            return collection
        }
        set {
            self[ObjectIdentifier(Tracing.Collection.self)] = newValue
        }
    }
}
