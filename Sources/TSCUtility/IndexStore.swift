/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2019 - 2020 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import TSCBasic
@_implementationOnly import TSCclibc

public final class IndexStore {

    public struct TestCaseClass {
        public struct TestMethod: Hashable, Comparable {
            public let name: String
            public let isAsync: Bool

            public static func < (lhs: IndexStore.TestCaseClass.TestMethod, rhs: IndexStore.TestCaseClass.TestMethod) -> Bool {
                return (lhs.name, (lhs.isAsync ? 1 : 0)) < (rhs.name, (rhs.isAsync ? 1 : 0))
            }
        }

        public var name: String
        public var module: String
        public var testMethods: [TestMethod]
        @available(*, deprecated, message: "use testMethods instead") public var methods: [String]
    }

    fileprivate var impl: IndexStoreImpl { _impl as! IndexStoreImpl }
    private let _impl: Any

    fileprivate init(_ impl: IndexStoreImpl) {
        self._impl = impl
    }

    static public func open(store path: AbsolutePath, api: IndexStoreAPI) throws -> IndexStore {
        let impl = try IndexStoreImpl.open(store: path, api: api.impl)
        return IndexStore(impl)
    }

    public func listTests(inObjectFile object: AbsolutePath) throws -> [TestCaseClass] {
        return try impl.listTests(inObjectFile: object)
    }
}

public final class IndexStoreAPI {
    fileprivate var impl: IndexStoreAPIImpl {
        _impl as! IndexStoreAPIImpl
    }
    private let _impl: Any

    public init(dylib path: AbsolutePath) throws {
        self._impl = try IndexStoreAPIImpl(dylib: path)
    }
}

private final class IndexStoreImpl {

    typealias TestCaseClass = IndexStore.TestCaseClass

    let api: IndexStoreAPIImpl

    var fn: indexstore_functions_t { api.fn }

    let store: indexstore_t

    private init(store: indexstore_t, api: IndexStoreAPIImpl) {
        self.store = store
        self.api = api
    }

    static public func open(store path: AbsolutePath, api: IndexStoreAPIImpl) throws -> IndexStoreImpl {
        if let store = try api.call({ api.fn.store_create(path.pathString, &$0) }) {
            return IndexStoreImpl(store: store, api: api)
        }
        throw StringError("Unable to open store at \(path)")
    }

    public func listTests(inObjectFile object: AbsolutePath) throws -> [TestCaseClass] {
        // Get the records of this object file.
        let unitReader = try api.call{ fn.unit_reader_create(store, unitName(object: object), &$0) }
        let records = try getRecords(unitReader: unitReader)

        // Get the test classes.
        let testCaseClasses = try records.flatMap{ try self.getTestCaseClasses(forRecord: $0) }

        // Fill the module name and return.
        let module = fn.unit_reader_get_module_name(unitReader).str
        return testCaseClasses.map {
            var c = $0
            c.module = module
            return c
        }
    }

    private func getTestCaseClasses(forRecord record: String) throws -> [TestCaseClass] {
        let recordReader = try api.call{ fn.record_reader_create(store, record, &$0) }

        class TestCaseBuilder {
            var classToMethods: [String: Set<TestCaseClass.TestMethod>] = [:]

            func add(className: String, method: TestCaseClass.TestMethod) {
                classToMethods[className, default: []].insert(method)
            }

            func build() -> [TestCaseClass] {
                return classToMethods.map {
                    let testMethods = Array($0.value).sorted()
                    return TestCaseClass(name: $0.key, module: "", testMethods: testMethods, methods: testMethods.map(\.name))
                }
            }
        }

        let builder = Ref(TestCaseBuilder(), api: api)

        let ctx = unsafeBitCast(Unmanaged.passUnretained(builder), to: UnsafeMutableRawPointer.self)
        _ = fn.record_reader_occurrences_apply_f(recordReader, ctx) { ctx , occ -> Bool in
            let builder = Unmanaged<Ref<TestCaseBuilder>>.fromOpaque(ctx!).takeUnretainedValue()
            let fn = builder.api.fn

            // Get the symbol.
            let sym = fn.occurrence_get_symbol(occ)
            let symbolProperties = fn.symbol_get_properties(sym)
            // We only care about symbols that are marked unit tests and are instance methods.
            if symbolProperties & UInt64(INDEXSTORE_SYMBOL_PROPERTY_UNITTEST.rawValue) == 0 {
                return true
            }
            if fn.symbol_get_kind(sym) != INDEXSTORE_SYMBOL_KIND_INSTANCEMETHOD {
                return true
            }

            let className = Ref("", api: builder.api)
            let ctx = unsafeBitCast(Unmanaged.passUnretained(className), to: UnsafeMutableRawPointer.self)

            _ = fn.occurrence_relations_apply_f(occ!, ctx) { ctx, relation in
                guard let relation = relation else { return true }
                let className = Unmanaged<Ref<String>>.fromOpaque(ctx!).takeUnretainedValue()
                let fn = className.api.fn

                // Look for the class.
                if fn.symbol_relation_get_roles(relation) != UInt64(INDEXSTORE_SYMBOL_ROLE_REL_CHILDOF.rawValue) {
                    return true
                }

                let sym = fn.symbol_relation_get_symbol(relation)
                className.instance = fn.symbol_get_name(sym).str
                return true
            }

            if !className.instance.isEmpty {
                let methodName = fn.symbol_get_name(sym).str
                let isAsync = symbolProperties & UInt64(INDEXSTORE_SYMBOL_PROPERTY_SWIFT_ASYNC.rawValue) != 0
                builder.instance.add(className: className.instance, method: TestCaseClass.TestMethod(name: methodName, isAsync: isAsync))
            }

            return true
        }

        return builder.instance.build()
    }

    private func getRecords(unitReader: indexstore_unit_reader_t?) throws -> [String] {
        let builder = Ref([String](), api: api)

        let ctx = unsafeBitCast(Unmanaged.passUnretained(builder), to: UnsafeMutableRawPointer.self)
        _ = fn.unit_reader_dependencies_apply_f(unitReader, ctx) { ctx , unit -> Bool in
            let store = Unmanaged<Ref<[String]>>.fromOpaque(ctx!).takeUnretainedValue()
            let fn = store.api.fn
            if fn.unit_dependency_get_kind(unit) == INDEXSTORE_UNIT_DEPENDENCY_RECORD {
                store.instance.append(fn.unit_dependency_get_name(unit).str)
            }
            return true
        }

        return builder.instance
    }

    private func unitName(object: AbsolutePath) -> String {
        let initialSize = 64
        var buf = UnsafeMutablePointer<CChar>.allocate(capacity: initialSize)
        let len = fn.store_get_unit_name_from_output_path(store, object.pathString, buf, initialSize)

        if len + 1 > initialSize {
            buf.deallocate()
            buf = UnsafeMutablePointer<CChar>.allocate(capacity: len + 1)
            _ = fn.store_get_unit_name_from_output_path(store, object.pathString, buf, len + 1)
        }

        defer {
            buf.deallocate()
        }

        return String(cString: buf)
    }
}

private class Ref<T> {
    let api: IndexStoreAPIImpl
    var instance: T
    init(_ instance: T, api: IndexStoreAPIImpl) {
        self.instance = instance
        self.api = api
    }
}

private final class IndexStoreAPIImpl {

    /// The path of the index store dylib.
    private let path: AbsolutePath

    /// Handle of the dynamic library.
    private let dylib: _DLHandle

    /// The index store API functions.
    fileprivate let fn: indexstore_functions_t

    fileprivate func call<T>(_ fn: (inout indexstore_error_t?) -> T) throws -> T {
        var error: indexstore_error_t? = nil
        let ret = fn(&error)

        if let error = error {
            if let desc = self.fn.error_get_description(error) {
                throw StringError(String(cString: desc))
            }
            throw StringError("Unable to get description for error: \(error)")
        }

        return ret
    }

    public init(dylib path: AbsolutePath) throws {
        self.path = path
#if os(Windows)
        let flags: _DLOpenFlags = []
#else
        let flags: _DLOpenFlags = [.lazy, .local, .first, .deepBind]
#endif
        self.dylib = try _dlopen(path.pathString, mode: flags)

        func dlsym_required<T>(_ handle: _DLHandle, symbol: String) throws -> T {
            guard let sym: T = _dlsym(handle, symbol: symbol) else {
                throw StringError("Missing required symbol: \(symbol)")
            }
            return sym
        }

        var api = indexstore_functions_t()
        api.store_create = try dlsym_required(dylib, symbol: "indexstore_store_create")
        api.store_get_unit_name_from_output_path = try dlsym_required(dylib, symbol: "indexstore_store_get_unit_name_from_output_path")
        api.unit_reader_create = try dlsym_required(dylib, symbol: "indexstore_unit_reader_create")
        api.error_get_description = try dlsym_required(dylib, symbol: "indexstore_error_get_description")
        api.unit_reader_dependencies_apply_f = try dlsym_required(dylib, symbol: "indexstore_unit_reader_dependencies_apply_f")
        api.unit_reader_get_module_name = try dlsym_required(dylib, symbol: "indexstore_unit_reader_get_module_name")
        api.unit_dependency_get_kind = try dlsym_required(dylib, symbol: "indexstore_unit_dependency_get_kind")
        api.unit_dependency_get_name = try dlsym_required(dylib, symbol: "indexstore_unit_dependency_get_name")
        api.record_reader_create = try dlsym_required(dylib, symbol: "indexstore_record_reader_create")
        api.symbol_get_name = try dlsym_required(dylib, symbol: "indexstore_symbol_get_name")
        api.symbol_get_properties = try dlsym_required(dylib, symbol: "indexstore_symbol_get_properties")
        api.symbol_get_kind = try dlsym_required(dylib, symbol: "indexstore_symbol_get_kind")
        api.record_reader_occurrences_apply_f = try dlsym_required(dylib, symbol: "indexstore_record_reader_occurrences_apply_f")
        api.occurrence_get_symbol = try dlsym_required(dylib, symbol: "indexstore_occurrence_get_symbol")
        api.occurrence_relations_apply_f = try dlsym_required(dylib, symbol: "indexstore_occurrence_relations_apply_f")
        api.symbol_relation_get_symbol = try dlsym_required(dylib, symbol: "indexstore_symbol_relation_get_symbol")
        api.symbol_relation_get_roles = try dlsym_required(dylib, symbol: "indexstore_symbol_relation_get_roles")

        self.fn = api
    }

    deinit {
        // FIXME: is it safe to dlclose() indexstore? If so, do that here. For now, let the handle leak.
        dylib.leak()
    }
}

extension indexstore_string_ref_t {
    fileprivate var str: String {
        return String(
            bytesNoCopy: UnsafeMutableRawPointer(mutating: data),
            length: length,
            encoding: .utf8,
            freeWhenDone: false
        )!
    }
}

// Private, non-deprecated copy of the dlopen code in `dlopen.swift` as we are planning to remove the public API in the next version.

import protocol Foundation.CustomNSError
import var Foundation.NSLocalizedDescriptionKey
import TSCLibc

private final class _DLHandle {
  #if os(Windows)
    typealias Handle = HMODULE
  #else
    typealias Handle = UnsafeMutableRawPointer
  #endif
    var rawValue: Handle? = nil

    init(rawValue: Handle) {
        self.rawValue = rawValue
    }

    deinit {
        precondition(rawValue == nil, "DLHandle must be closed or explicitly leaked before destroying")
    }

    public func close() throws {
        if let handle = rawValue {
          #if os(Windows)
            guard FreeLibrary(handle) else {
                throw _DLError.close("Failed to FreeLibrary: \(GetLastError())")
            }
          #else
            guard dlclose(handle) == 0 else {
                throw _DLError.close(_dlerror() ?? "unknown error")
            }
          #endif
        }
        rawValue = nil
    }

    public func leak() {
        rawValue = nil
    }
}

private struct _DLOpenFlags: RawRepresentable, OptionSet {

  #if !os(Windows)
    public static let lazy: _DLOpenFlags = _DLOpenFlags(rawValue: RTLD_LAZY)
    public static let now: _DLOpenFlags = _DLOpenFlags(rawValue: RTLD_NOW)
    public static let local: _DLOpenFlags = _DLOpenFlags(rawValue: RTLD_LOCAL)
    public static let global: _DLOpenFlags = _DLOpenFlags(rawValue: RTLD_GLOBAL)

    // Platform-specific flags.
  #if canImport(Darwin)
    public static let first: _DLOpenFlags = _DLOpenFlags(rawValue: RTLD_FIRST)
    public static let deepBind: _DLOpenFlags = _DLOpenFlags(rawValue: 0)
  #else
    public static let first: _DLOpenFlags = _DLOpenFlags(rawValue: 0)
  #if os(Linux)
    public static let deepBind: _DLOpenFlags = _DLOpenFlags(rawValue: RTLD_DEEPBIND)
  #else
    public static let deepBind: _DLOpenFlags = _DLOpenFlags(rawValue: 0)
  #endif
  #endif
  #endif

    public var rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
}

private enum _DLError: Error {
    case `open`(String)
    case close(String)
}

extension _DLError: CustomNSError {
    public var errorUserInfo: [String : Any] {
        return [NSLocalizedDescriptionKey: "\(self)"]
    }
}

private func _dlsym<T>(_ handle: _DLHandle, symbol: String) -> T? {
  #if os(Windows)
    guard let ptr = GetProcAddress(handle.rawValue!, symbol) else {
        return nil
    }
  #else
    guard let ptr = dlsym(handle.rawValue!, symbol) else {
        return nil
    }
  #endif
    return unsafeBitCast(ptr, to: T.self)
}

private func _dlopen(_ path: String?, mode: _DLOpenFlags) throws -> _DLHandle {
  #if os(Windows)
    guard let handle = path?.withCString(encodedAs: UTF16.self, LoadLibraryW) else {
        throw _DLError.open("LoadLibraryW failed: \(GetLastError())")
    }
  #else
    guard let handle = TSCLibc.dlopen(path, mode.rawValue) else {
        throw _DLError.open(_dlerror() ?? "unknown error")
    }
  #endif
    return _DLHandle(rawValue: handle)
}

private func _dlclose(_ handle: _DLHandle) throws {
    try handle.close()
}

#if !os(Windows)
private func _dlerror() -> String? {
    if let err: UnsafeMutablePointer<Int8> = dlerror() {
        return String(cString: err)
    }
    return nil
}
#endif
