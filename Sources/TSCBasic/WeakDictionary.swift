/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

/// A dictionary that only keeps weak references to its values.
struct WeakDictionary<Key: Hashable, Value: AnyObject> {

    private struct WeakReference<Value: AnyObject> {
        weak var reference: Value?

        init(_ value: Value?) {
            self.reference = value
        }
    }

    private var storage = Dictionary<Key, WeakReference<Value>>()

    subscript(key: Key) -> Value? {
        get { storage[key]?.reference }
        set(newValue) { storage[key] = WeakReference(newValue) }
    }
}
