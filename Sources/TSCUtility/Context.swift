/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import _Concurrency


public struct Context {
    private var backing: [ObjectIdentifier: Any] = [:]

#if compiler(>=5.5.2)
    @available(*, deprecated, message: "Values should be Sendable")
    @_disfavoredOverload
    public init(dictionaryLiteral keyValuePairs: (ObjectIdentifier, Any)...) {
        self.backing = Dictionary(uniqueKeysWithValues: keyValuePairs)
    }

    public init(dictionaryLiteral keyValuePairs: (ObjectIdentifier, Sendable)...) {
        self.backing = Dictionary(uniqueKeysWithValues: keyValuePairs)
    }

    @available(*, deprecated, message: "Values should be Sendable")
    @_disfavoredOverload
    public subscript(key: ObjectIdentifier) -> Any? {
        get {
            return self.backing[key]
        }
        set {
            self.backing[key] = newValue
        }
    }

    public subscript<Value>(key: ObjectIdentifier, as type: Value.Type = Value.self) -> Value? where Value: Sendable {
        get {
            return self.backing[key] as? Value
        }
        set {
            self.backing[key] = newValue
        }
    }
#else
    public init(dictionaryLiteral keyValuePairs: (ObjectIdentifier, Any)...) {
        self.backing = Dictionary(uniqueKeysWithValues: keyValuePairs)
    }

    @_disfavoredOverload
    public subscript(key: ObjectIdentifier) -> Any? {
        get {
            return self.backing[key]
        }
        set {
            self.backing[key] = newValue
        }
    }

    public subscript<Value>(key: ObjectIdentifier, as type: Value.Type = Value.self) -> Value? {
        get {
            return self.backing[key] as? Value
        }
        set {
            self.backing[key] = newValue
        }
    }
#endif
}

#if compiler(>=5.7)
extension Context: /* until we can remove the support for 'Any' values */ @unchecked Sendable {}
#else
#if compiler(>=5.5.2)
extension Context: UnsafeSendable {}
#endif
#endif

@available(*, deprecated, renamed: "init()")
extension Context: ExpressibleByDictionaryLiteral {
    public typealias Key = ObjectIdentifier
    public typealias Value = Any
}

extension Context {
#if compiler(>=5.5.2)
    /// Get the value for the given type.
    @available(*, deprecated, message: "Values should be Sendable")
    @_disfavoredOverload
    public func get<T>(_ type: T.Type = T.self) -> T {
        guard let value = getOptional(type) else {
            fatalError("no type \(T.self) in context")
        }
        return value
    }

    public func get<T: Sendable>(_ type: T.Type = T.self) -> T {
        guard let value = self.getOptional(type) else {
            fatalError("no type \(T.self) in context")
        }
        return value
    }

    /// Get the value for the given type, if present.
    @available(*, deprecated, message: "Values should be Sendable")
    @_disfavoredOverload
    public func getOptional<T>(_ type: T.Type = T.self) -> T? {
        guard let value = self[ObjectIdentifier(T.self)] else {
            return nil
        }
        return value as? T
    }

    /// Get the value for the given type, if present.
    public func getOptional<T: Sendable>(_ type: T.Type = T.self) -> T? {
        return self[ObjectIdentifier(T.self)]
    }

    /// Set a context value for a type.
    @available(*, deprecated, message: "Values should be Sendable")
    @_disfavoredOverload
    public mutating func set<T>(_ value: T) {
        self[ObjectIdentifier(T.self)] = value
    }

    public mutating func set<Value: Sendable>(_ value: Value) {
        self[ObjectIdentifier(Value.self)] = value
    }
#else
    /// Get the value for the given type.
    public func get<T>(_ type: T.Type = T.self) -> T {
        guard let value = getOptional(type) else {
            fatalError("no type \(T.self) in context")
        }
        return value
    }

    /// Get the value for the given type, if present.
    public func getOptional<T>(_ type: T.Type = T.self) -> T? {
        guard let value = self[ObjectIdentifier(T.self)] else {
            return nil
        }
        return value as? T
    }

    /// Set a context value for a type.
    public mutating func set<T>(_ value: T) {
        self[ObjectIdentifier(T.self)] = value
    }
#endif
}
