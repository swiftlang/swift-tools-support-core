/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation

import TSCBasic
import TSCTestSupport

class PathTests: XCTestCase {

    func testBasics() {
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").pathString, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/a").pathString, "/a")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/a/b/c").pathString, "/a/b/c")
        XCTAssertEqual(RelativePath(".").pathString, ".")
        XCTAssertEqual(RelativePath("a").pathString, "a")
        XCTAssertEqual(RelativePath("a/b/c").pathString, "a/b/c")
        XCTAssertEqual(RelativePath("~").pathString, "~")  // `~` is not special
    }

    func testStringInitialization() {
        let abs1 = AbsolutePath.withPOSIX(path: "/")
        let abs2 = AbsolutePath(abs1, ".")
        XCTAssertEqual(abs1, abs2)
        let rel3 = "."
        let abs3 = AbsolutePath(abs2, rel3)
        XCTAssertEqual(abs2, abs3)
        let base = AbsolutePath.withPOSIX(path: "/base/path")
        let abs4 = AbsolutePath("/a/b/c", relativeTo: base)
        XCTAssertEqual(abs4, AbsolutePath.withPOSIX(path: "/a/b/c"))
        let abs5 = AbsolutePath("./a/b/c", relativeTo: base)
        XCTAssertEqual(abs5, AbsolutePath.withPOSIX(path: "/base/path/a/b/c"))
        let abs6 = AbsolutePath("~/bla", relativeTo: base)  // `~` isn't special
        XCTAssertEqual(abs6, AbsolutePath.withPOSIX(path: "/base/path/~/bla"))
    }

    func testStringLiteralInitialization() {
        let abs = AbsolutePath.withPOSIX(path: "/")
        XCTAssertEqual(abs.pathString, "/")
        let rel1 = RelativePath(".")
        XCTAssertEqual(rel1.pathString, ".")
        let rel2 = RelativePath("~")
        XCTAssertEqual(rel2.pathString, "~")  // `~` is not special
    }

    func testRepeatedPathSeparators() {
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/ab//cd//ef").pathString, "/ab/cd/ef")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/ab///cd//ef").pathString, "/ab/cd/ef")
        XCTAssertEqual(RelativePath("ab//cd//ef").pathString, "ab/cd/ef")
        XCTAssertEqual(RelativePath("ab//cd///ef").pathString, "ab/cd/ef")
    }

    func testTrailingPathSeparators() {
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/ab/cd/ef/").pathString, "/ab/cd/ef")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/ab/cd/ef//").pathString, "/ab/cd/ef")
        XCTAssertEqual(RelativePath("ab/cd/ef/").pathString, "ab/cd/ef")
        XCTAssertEqual(RelativePath("ab/cd/ef//").pathString, "ab/cd/ef")
    }

    func testDotPathComponents() {
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/ab/././cd//ef").pathString, "/ab/cd/ef")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/ab/./cd//ef/.").pathString, "/ab/cd/ef")
        XCTAssertEqual(RelativePath("ab/./cd/././ef").pathString, "ab/cd/ef")
        XCTAssertEqual(RelativePath("ab/./cd/ef/.").pathString, "ab/cd/ef")
    }

    func testDotDotPathComponents() {
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/..").pathString, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/../../../../..").pathString, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/abc/..").pathString, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/abc/../..").pathString, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/../abc").pathString, "/abc")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/../abc/..").pathString, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/../abc/../def").pathString, "/def")
        XCTAssertEqual(RelativePath("..").pathString, "..")
        XCTAssertEqual(RelativePath("../..").pathString, "../..")
        XCTAssertEqual(RelativePath(".././..").pathString, "../..")
        XCTAssertEqual(RelativePath("../abc/..").pathString, "..")
        XCTAssertEqual(RelativePath("../abc/.././").pathString, "..")
        XCTAssertEqual(RelativePath("abc/..").pathString, ".")
    }

    func testCombinationsAndEdgeCases() {
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "///").pathString, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/./").pathString, "/")
        XCTAssertEqual(RelativePath("").pathString, ".")
        XCTAssertEqual(RelativePath(".").pathString, ".")
        XCTAssertEqual(RelativePath("./abc").pathString, "abc")
        XCTAssertEqual(RelativePath("./abc/").pathString, "abc")
        XCTAssertEqual(RelativePath("./abc/../bar").pathString, "bar")
        XCTAssertEqual(RelativePath("foo/../bar").pathString, "bar")
        XCTAssertEqual(RelativePath("foo///..///bar///baz").pathString, "bar/baz")
        XCTAssertEqual(RelativePath("foo/../bar/./").pathString, "bar")
        XCTAssertEqual(RelativePath("../abc/def/").pathString, "../abc/def")
        XCTAssertEqual(RelativePath("././././.").pathString, ".")
        XCTAssertEqual(RelativePath("./././../.").pathString, "..")
        XCTAssertEqual(RelativePath("./").pathString, ".")
        XCTAssertEqual(RelativePath(".//").pathString, ".")
        XCTAssertEqual(RelativePath("./.").pathString, ".")
        XCTAssertEqual(RelativePath("././").pathString, ".")
        XCTAssertEqual(RelativePath("../").pathString, "..")
        XCTAssertEqual(RelativePath("../.").pathString, "..")
        XCTAssertEqual(RelativePath("./..").pathString, "..")
        XCTAssertEqual(RelativePath("./../.").pathString, "..")
        XCTAssertEqual(RelativePath("./////../////./////").pathString, "..")
        XCTAssertEqual(RelativePath("../a").pathString, "../a")
        XCTAssertEqual(RelativePath("../a/..").pathString, "..")
        XCTAssertEqual(RelativePath("a/..").pathString, ".")
        XCTAssertEqual(RelativePath("a/../////../////./////").pathString, "..")
    }

    func testDirectoryNameExtraction() {
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").dirname, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/a").dirname, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/./a").dirname, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/../..").dirname, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/ab/c//d/").dirname, "/ab/c")
        XCTAssertEqual(RelativePath("ab/c//d/").dirname, "ab/c")
        XCTAssertEqual(RelativePath("../a").dirname, "..")
        XCTAssertEqual(RelativePath("../a/..").dirname, ".")
        XCTAssertEqual(RelativePath("a/..").dirname, ".")
        XCTAssertEqual(RelativePath("./..").dirname, ".")
        XCTAssertEqual(RelativePath("a/../////../////./////").dirname, ".")
        XCTAssertEqual(RelativePath("abc").dirname, ".")
        XCTAssertEqual(RelativePath("").dirname, ".")
        XCTAssertEqual(RelativePath(".").dirname, ".")
    }

    func testBaseNameExtraction() {
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").basename, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/a").basename, "a")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/./a").basename, "a")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/../..").basename, "/")
        XCTAssertEqual(RelativePath("../..").basename, "..")
        XCTAssertEqual(RelativePath("../a").basename, "a")
        XCTAssertEqual(RelativePath("../a/..").basename, "..")
        XCTAssertEqual(RelativePath("a/..").basename, ".")
        XCTAssertEqual(RelativePath("./..").basename, "..")
        XCTAssertEqual(RelativePath("a/../////../////./////").basename, "..")
        XCTAssertEqual(RelativePath("abc").basename, "abc")
        XCTAssertEqual(RelativePath("").basename, ".")
        XCTAssertEqual(RelativePath(".").basename, ".")
    }

    func testBaseNameWithoutExt() {
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").basenameWithoutExt, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/a").basenameWithoutExt, "a")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/./a").basenameWithoutExt, "a")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/../..").basenameWithoutExt, "/")
        XCTAssertEqual(RelativePath("../..").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath("../a").basenameWithoutExt, "a")
        XCTAssertEqual(RelativePath("../a/..").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath("a/..").basenameWithoutExt, ".")
        XCTAssertEqual(RelativePath("./..").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath("a/../////../////./////").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath("abc").basenameWithoutExt, "abc")
        XCTAssertEqual(RelativePath("").basenameWithoutExt, ".")
        XCTAssertEqual(RelativePath(".").basenameWithoutExt, ".")

        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/a.txt").basenameWithoutExt, "a")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/./a.txt").basenameWithoutExt, "a")
        XCTAssertEqual(RelativePath("../a.bc").basenameWithoutExt, "a")
        XCTAssertEqual(RelativePath("abc.swift").basenameWithoutExt, "abc")
        XCTAssertEqual(RelativePath("../a.b.c").basenameWithoutExt, "a.b")
        XCTAssertEqual(RelativePath("abc.xyz.123").basenameWithoutExt, "abc.xyz")
    }

    func testSuffixExtraction() {
        XCTAssertEqual(RelativePath("a").suffix, nil)
        XCTAssertEqual(RelativePath("a").extension, nil)
        XCTAssertEqual(RelativePath("a.").suffix, nil)
        XCTAssertEqual(RelativePath("a.").extension, nil)
        XCTAssertEqual(RelativePath(".a").suffix, nil)
        XCTAssertEqual(RelativePath(".a").extension, nil)
        XCTAssertEqual(RelativePath("").suffix, nil)
        XCTAssertEqual(RelativePath("").extension, nil)
        XCTAssertEqual(RelativePath(".").suffix, nil)
        XCTAssertEqual(RelativePath(".").extension, nil)
        XCTAssertEqual(RelativePath("..").suffix, nil)
        XCTAssertEqual(RelativePath("..").extension, nil)
        XCTAssertEqual(RelativePath("a.foo").suffix, ".foo")
        XCTAssertEqual(RelativePath("a.foo").extension, "foo")
        XCTAssertEqual(RelativePath(".a.foo").suffix, ".foo")
        XCTAssertEqual(RelativePath(".a.foo").extension, "foo")
        XCTAssertEqual(RelativePath(".a.foo.bar").suffix, ".bar")
        XCTAssertEqual(RelativePath(".a.foo.bar").extension, "bar")
        XCTAssertEqual(RelativePath("a.foo.bar").suffix, ".bar")
        XCTAssertEqual(RelativePath("a.foo.bar").extension, "bar")
        XCTAssertEqual(RelativePath(".a.foo.bar.baz").suffix, ".baz")
        XCTAssertEqual(RelativePath(".a.foo.bar.baz").extension, "baz")
    }

    func testParentDirectory() {
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").parentDirectory, AbsolutePath.withPOSIX(path: "/"))
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").parentDirectory.parentDirectory, AbsolutePath.withPOSIX(path: "/"))
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/bar").parentDirectory, AbsolutePath.withPOSIX(path: "/"))
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/bar/../foo/..//").parentDirectory.parentDirectory, AbsolutePath.withPOSIX(path: "/"))
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/bar/../foo/..//yabba/a/b").parentDirectory.parentDirectory, AbsolutePath.withPOSIX(path: "/yabba"))
    }

    func testConcatenation() {
        XCTAssertEqual(AbsolutePath(AbsolutePath.withPOSIX(path: "/"), RelativePath("")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath.withPOSIX(path: "/"), RelativePath(".")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath.withPOSIX(path: "/"), RelativePath("..")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath.withPOSIX(path: "/"), RelativePath("bar")).pathString, "/bar")
        XCTAssertEqual(AbsolutePath(AbsolutePath.withPOSIX(path: "/foo/bar"), RelativePath("..")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath(AbsolutePath.withPOSIX(path: "/bar"), RelativePath("../foo")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath(AbsolutePath.withPOSIX(path: "/bar"), RelativePath("../foo/..//")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath.withPOSIX(path: "/bar/../foo/..//yabba/"), RelativePath("a/b")).pathString, "/yabba/a/b")

        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").appending(RelativePath("")).pathString, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").appending(RelativePath(".")).pathString, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").appending(RelativePath("..")).pathString, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").appending(RelativePath("bar")).pathString, "/bar")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/foo/bar").appending(RelativePath("..")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/bar").appending(RelativePath("../foo")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/bar").appending(RelativePath("../foo/..//")).pathString, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/bar/../foo/..//yabba/").appending(RelativePath("a/b")).pathString, "/yabba/a/b")

        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").appending(component: "a").pathString, "/a")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/a").appending(component: "b").pathString, "/a/b")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").appending(components: "a", "b").pathString, "/a/b")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/a").appending(components: "b", "c").pathString, "/a/b/c")

        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/a/b/c").appending(components: ".").pathString, "/a/b/c")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/a/b/c").appending(components: "..").pathString, "/a/b")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/a/b/c").appending(components: "..", "d").pathString, "/a/b/d")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").appending(components: "..").pathString, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").appending(components: ".").pathString, "/")
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").appending(components: "..", "a").pathString, "/a")

        XCTAssertEqual(RelativePath("hello").appending(components: "a", "b", "c", "..").pathString, "hello/a/b")
        XCTAssertEqual(RelativePath("hello").appending(RelativePath("a/b/../c/d")).pathString, "hello/a/c/d")
    }

    func testPathComponents() {
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/").components, [])
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/.").components, [])
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/..").components, [])
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/bar").components, ["bar"])
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/foo/bar/..").components, ["foo"])
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/bar/../foo").components, ["foo"])
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/bar/../foo/..//").components, [])
        XCTAssertEqual(AbsolutePath.withPOSIX(path: "/bar/../foo/..//yabba/a/b/").components, ["yabba", "a", "b"])

        XCTAssertEqual(RelativePath("").components, ["."])
        XCTAssertEqual(RelativePath(".").components, ["."])
        XCTAssertEqual(RelativePath("..").components, [".."])
        XCTAssertEqual(RelativePath("bar").components, ["bar"])
        XCTAssertEqual(RelativePath("foo/bar/..").components, ["foo"])
        XCTAssertEqual(RelativePath("bar/../foo").components, ["foo"])
        XCTAssertEqual(RelativePath("bar/../foo/..//").components, ["."])
        XCTAssertEqual(RelativePath("bar/../foo/..//yabba/a/b/").components, ["yabba", "a", "b"])
        XCTAssertEqual(RelativePath("../..").components, ["..", ".."])
        XCTAssertEqual(RelativePath(".././/..").components, ["..", ".."])
        XCTAssertEqual(RelativePath("../a").components, ["..", "a"])
        XCTAssertEqual(RelativePath("../a/..").components, [".."])
        XCTAssertEqual(RelativePath("a/..").components, ["."])
        XCTAssertEqual(RelativePath("./..").components, [".."])
        XCTAssertEqual(RelativePath("a/../////../////./////").components, [".."])
        XCTAssertEqual(RelativePath("abc").components, ["abc"])
    }

    func testRelativePathFromAbsolutePaths() {
        XCTAssertEqual(try! AbsolutePath.withPOSIX(path: "/").relative(to: AbsolutePath.withPOSIX(path: "/")), RelativePath("."));
        XCTAssertEqual(try! AbsolutePath.withPOSIX(path: "/a/b/c/d").relative(to: AbsolutePath.withPOSIX(path: "/")), RelativePath("a/b/c/d"));
        XCTAssertEqual(try! AbsolutePath.withPOSIX(path: "/").relative(to: AbsolutePath.withPOSIX(path: "/a/b/c")), RelativePath("../../.."));
        XCTAssertEqual(try! AbsolutePath.withPOSIX(path: "/a/b/c/d").relative(to: AbsolutePath.withPOSIX(path: "/a/b")), RelativePath("c/d"));
        XCTAssertEqual(try! AbsolutePath.withPOSIX(path: "/a/b/c/d").relative(to: AbsolutePath.withPOSIX(path: "/a/b/c")), RelativePath("d"));
        XCTAssertEqual(try! AbsolutePath.withPOSIX(path: "/a/b/c/d").relative(to: AbsolutePath.withPOSIX(path: "/a/c/d")), RelativePath("../../b/c/d"));
        XCTAssertEqual(try! AbsolutePath.withPOSIX(path: "/a/b/c/d").relative(to: AbsolutePath.withPOSIX(path: "/b/c/d")), RelativePath("../../../a/b/c/d"));
    }

    func testComparison() {
        XCTAssertTrue(AbsolutePath.withPOSIX(path: "/") <= AbsolutePath.withPOSIX(path: "/"));
        XCTAssertTrue(AbsolutePath.withPOSIX(path: "/abc") < AbsolutePath.withPOSIX(path: "/def"));
        XCTAssertTrue(AbsolutePath.withPOSIX(path: "/2") <= AbsolutePath.withPOSIX(path: "/2.1"));
        XCTAssertTrue(AbsolutePath.withPOSIX(path: "/3.1") > AbsolutePath.withPOSIX(path: "/2"));
        XCTAssertTrue(AbsolutePath.withPOSIX(path: "/2") >= AbsolutePath.withPOSIX(path: "/2"));
        XCTAssertTrue(AbsolutePath.withPOSIX(path: "/2.1") >= AbsolutePath.withPOSIX(path: "/2"));
    }

    func testContains() {
        XCTAssertTrue(AbsolutePath.withPOSIX(path: "/a/b/c/d/e/f").contains(AbsolutePath.withPOSIX(path: "/a/b/c/d")))
        XCTAssertTrue(AbsolutePath.withPOSIX(path: "/a/b/c/d/e/f.swift").contains(AbsolutePath.withPOSIX(path: "/a/b/c")))
        XCTAssertTrue(AbsolutePath.withPOSIX(path: "/").contains(AbsolutePath.withPOSIX(path: "/")))
        XCTAssertTrue(AbsolutePath.withPOSIX(path: "/foo/bar").contains(AbsolutePath.withPOSIX(path: "/")))
        XCTAssertFalse(AbsolutePath.withPOSIX(path: "/foo/bar").contains(AbsolutePath.withPOSIX(path: "/foo/bar/baz")))
        XCTAssertFalse(AbsolutePath.withPOSIX(path: "/foo/bar").contains(AbsolutePath.withPOSIX(path: "/bar")))
    }

    func testAbsolutePathValidation() {
        XCTAssertNoThrow(try AbsolutePath(validating: "/a/b/c/d"))

        XCTAssertThrowsError(try AbsolutePath(validating: "~/a/b/d")) { error in
            XCTAssertEqual("\(error)", "invalid absolute path '~/a/b/d'")
        }

        XCTAssertThrowsError(try AbsolutePath(validating: "a/b/d")) { error in
            XCTAssertEqual("\(error)", "invalid absolute path 'a/b/d'")
        }
    }

    func testRelativePathValidation() {
        XCTAssertNoThrow(try RelativePath(validating: "a/b/c/d"))

        XCTAssertThrowsError(try RelativePath(validating: "/a/b/d")) { error in
            XCTAssertEqual("\(error)", "invalid relative path '/a/b/d'")
        }

        XCTAssertThrowsError(try RelativePath(validating: "~/a/b/d")) { error in
            XCTAssertEqual("\(error)", "invalid relative path '~/a/b/d'")
        }
    }

    func testCodable() throws {
        struct Foo: Codable, Equatable {
            var path: AbsolutePath
        }

        struct Bar: Codable, Equatable {
            var path: RelativePath
        }

        struct Baz: Codable, Equatable {
            var path: String
        }

        do {
            let foo = Foo(path: AbsolutePath.withPOSIX(path: "/path/to/foo"))
            let data = try JSONEncoder().encode(foo)
            let decodedFoo = try JSONDecoder().decode(Foo.self, from: data)
            XCTAssertEqual(foo, decodedFoo)
        }

        do {
            let foo = Foo(path: AbsolutePath.withPOSIX(path: "/path/to/../to/foo"))
            let data = try JSONEncoder().encode(foo)
            let decodedFoo = try JSONDecoder().decode(Foo.self, from: data)
            XCTAssertEqual(foo, decodedFoo)
            XCTAssertEqual(foo.path.pathString, "/path/to/foo")
            XCTAssertEqual(decodedFoo.path.pathString, "/path/to/foo")
        }

        do {
            let bar = Bar(path: RelativePath("path/to/bar"))
            let data = try JSONEncoder().encode(bar)
            let decodedBar = try JSONDecoder().decode(Bar.self, from: data)
            XCTAssertEqual(bar, decodedBar)
        }

        do {
            let bar = Bar(path: RelativePath("path/to/../to/bar"))
            let data = try JSONEncoder().encode(bar)
            let decodedBar = try JSONDecoder().decode(Bar.self, from: data)
            XCTAssertEqual(bar, decodedBar)
            XCTAssertEqual(bar.path.pathString, "path/to/bar")
            XCTAssertEqual(decodedBar.path.pathString, "path/to/bar")
        }

        do {
            let data = try JSONEncoder().encode(Baz(path: ""))
            XCTAssertThrowsError(try JSONDecoder().decode(Foo.self, from: data))
            XCTAssertNoThrow(try JSONDecoder().decode(Bar.self, from: data)) // empty string is a valid relative path
        }

        do {
            let data = try JSONEncoder().encode(Baz(path: "foo"))
            XCTAssertThrowsError(try JSONDecoder().decode(Foo.self, from: data))
        }

        do {
            let data = try JSONEncoder().encode(Baz(path: "/foo"))
            XCTAssertThrowsError(try JSONDecoder().decode(Bar.self, from: data))
        }
    }

    // FIXME: We also need tests for join() operations.

    // FIXME: We also need tests for dirname, basename, suffix, etc.

    // FIXME: We also need test for stat() operations.
}
