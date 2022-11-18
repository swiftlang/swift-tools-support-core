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

class PathTests: XCTestCase {

    func testBasics() {
        XCTAssertEqual(AbsolutePath(static: "/").pathString, "/")
        XCTAssertEqual(AbsolutePath(static: "/a").pathString, "/a")
        XCTAssertEqual(AbsolutePath(static: "/a/b/c").pathString, "/a/b/c")
        XCTAssertEqual(RelativePath(static: ".").pathString, ".")
        XCTAssertEqual(RelativePath(static: "a").pathString, "a")
        XCTAssertEqual(RelativePath(static: "a/b/c").pathString, "a/b/c")
        XCTAssertEqual(RelativePath(static: "~").pathString, "~")  // `~` is not special
    }

    func testStringInitialization() throws {
        let abs1 = AbsolutePath(static: "/")
        let abs2 = AbsolutePath(base: abs1, ".")
        XCTAssertEqual(abs1, abs2)
        let rel3 = "."
        let abs3 = try AbsolutePath(abs2, validating: rel3)
        XCTAssertEqual(abs2, abs3)
        let base = AbsolutePath(static: "/base/path")
        let abs4 = AbsolutePath(static: "/a/b/c", relativeTo: base)
        XCTAssertEqual(abs4, AbsolutePath(static: "/a/b/c"))
        let abs5 = AbsolutePath(static: "./a/b/c", relativeTo: base)
        XCTAssertEqual(abs5, AbsolutePath(static: "/base/path/a/b/c"))
        let abs6 = AbsolutePath(static: "~/bla", relativeTo: base)  // `~` isn't special
        XCTAssertEqual(abs6, AbsolutePath(static: "/base/path/~/bla"))
    }

    func testStringLiteralInitialization() {
        let abs = AbsolutePath(static: "/")
        XCTAssertEqual(abs.pathString, "/")
        let rel1 = RelativePath(static: ".")
        XCTAssertEqual(rel1.pathString, ".")
        let rel2 = RelativePath(static: "~")
        XCTAssertEqual(rel2.pathString, "~")  // `~` is not special
    }

    func testRepeatedPathSeparators() {
        XCTAssertEqual(AbsolutePath(static: "/ab//cd//ef").pathString, "/ab/cd/ef")
        XCTAssertEqual(AbsolutePath(static: "/ab///cd//ef").pathString, "/ab/cd/ef")
        XCTAssertEqual(RelativePath(static: "ab//cd//ef").pathString, "ab/cd/ef")
        XCTAssertEqual(RelativePath(static: "ab//cd///ef").pathString, "ab/cd/ef")
    }

    func testTrailingPathSeparators() {
        XCTAssertEqual(AbsolutePath(static: "/ab/cd/ef/").pathString, "/ab/cd/ef")
        XCTAssertEqual(AbsolutePath(static: "/ab/cd/ef//").pathString, "/ab/cd/ef")
        XCTAssertEqual(RelativePath(static: "ab/cd/ef/").pathString, "ab/cd/ef")
        XCTAssertEqual(RelativePath(static: "ab/cd/ef//").pathString, "ab/cd/ef")
    }

    func testDotPathComponents() {
        XCTAssertEqual(AbsolutePath(static: "/ab/././cd//ef").pathString, "/ab/cd/ef")
        XCTAssertEqual(AbsolutePath(static: "/ab/./cd//ef/.").pathString, "/ab/cd/ef")
        XCTAssertEqual(RelativePath(static: "ab/./cd/././ef").pathString, "ab/cd/ef")
        XCTAssertEqual(RelativePath(static: "ab/./cd/ef/.").pathString, "ab/cd/ef")
    }

    func testDotDotPathComponents() {
        XCTAssertEqual(AbsolutePath(static: "/..").pathString, "/")
        XCTAssertEqual(AbsolutePath(static: "/../../../../..").pathString, "/")
        XCTAssertEqual(AbsolutePath(static: "/abc/..").pathString, "/")
        XCTAssertEqual(AbsolutePath(static: "/abc/../..").pathString, "/")
        XCTAssertEqual(AbsolutePath(static: "/../abc").pathString, "/abc")
        XCTAssertEqual(AbsolutePath(static: "/../abc/..").pathString, "/")
        XCTAssertEqual(AbsolutePath(static: "/../abc/../def").pathString, "/def")
        XCTAssertEqual(RelativePath(static: "..").pathString, "..")
        XCTAssertEqual(RelativePath(static: "../..").pathString, "../..")
        XCTAssertEqual(RelativePath(static: ".././..").pathString, "../..")
        XCTAssertEqual(RelativePath(static: "../abc/..").pathString, "..")
        XCTAssertEqual(RelativePath(static: "../abc/.././").pathString, "..")
        XCTAssertEqual(RelativePath(static: "abc/..").pathString, ".")
    }

    func testCombinationsAndEdgeCases() {
        XCTAssertEqual(AbsolutePath(static: "///").pathString, "/")
        XCTAssertEqual(AbsolutePath(static: "/./").pathString, "/")
        XCTAssertEqual(RelativePath(static: "").pathString, ".")
        XCTAssertEqual(RelativePath(static: ".").pathString, ".")
        XCTAssertEqual(RelativePath(static: "./abc").pathString, "abc")
        XCTAssertEqual(RelativePath(static: "./abc/").pathString, "abc")
        XCTAssertEqual(RelativePath(static: "./abc/../bar").pathString, "bar")
        XCTAssertEqual(RelativePath(static: "foo/../bar").pathString, "bar")
        XCTAssertEqual(RelativePath(static: "foo///..///bar///baz").pathString, "bar/baz")
        XCTAssertEqual(RelativePath(static: "foo/../bar/./").pathString, "bar")
        XCTAssertEqual(RelativePath(static: "../abc/def/").pathString, "../abc/def")
        XCTAssertEqual(RelativePath(static: "././././.").pathString, ".")
        XCTAssertEqual(RelativePath(static: "./././../.").pathString, "..")
        XCTAssertEqual(RelativePath(static: "./").pathString, ".")
        XCTAssertEqual(RelativePath(static: ".//").pathString, ".")
        XCTAssertEqual(RelativePath(static: "./.").pathString, ".")
        XCTAssertEqual(RelativePath(static: "././").pathString, ".")
        XCTAssertEqual(RelativePath(static: "../").pathString, "..")
        XCTAssertEqual(RelativePath(static: "../.").pathString, "..")
        XCTAssertEqual(RelativePath(static: "./..").pathString, "..")
        XCTAssertEqual(RelativePath(static: "./../.").pathString, "..")
        XCTAssertEqual(RelativePath(static: "./////../////./////").pathString, "..")
        XCTAssertEqual(RelativePath(static: "../a").pathString, "../a")
        XCTAssertEqual(RelativePath(static: "../a/..").pathString, "..")
        XCTAssertEqual(RelativePath(static: "a/..").pathString, ".")
        XCTAssertEqual(RelativePath(static: "a/../////../////./////").pathString, "..")
    }

    func testDirectoryNameExtraction() {
        XCTAssertEqual(AbsolutePath(static: "/").dirname, "/")
        XCTAssertEqual(AbsolutePath(static: "/a").dirname, "/")
        XCTAssertEqual(AbsolutePath(static: "/./a").dirname, "/")
        XCTAssertEqual(AbsolutePath(static: "/../..").dirname, "/")
        XCTAssertEqual(AbsolutePath(static: "/ab/c//d/").dirname, "/ab/c")
        XCTAssertEqual(RelativePath(static: "ab/c//d/").dirname, "ab/c")
        XCTAssertEqual(RelativePath(static: "../a").dirname, "..")
        XCTAssertEqual(RelativePath(static: "../a/..").dirname, ".")
        XCTAssertEqual(RelativePath(static: "a/..").dirname, ".")
        XCTAssertEqual(RelativePath(static: "./..").dirname, ".")
        XCTAssertEqual(RelativePath(static: "a/../////../////./////").dirname, ".")
        XCTAssertEqual(RelativePath(static: "abc").dirname, ".")
        XCTAssertEqual(RelativePath(static: "").dirname, ".")
        XCTAssertEqual(RelativePath(static: ".").dirname, ".")
    }

    func testBaseNameExtraction() {
        XCTAssertEqual(AbsolutePath(static: "/").basename, "/")
        XCTAssertEqual(AbsolutePath(static: "/a").basename, "a")
        XCTAssertEqual(AbsolutePath(static: "/./a").basename, "a")
        XCTAssertEqual(AbsolutePath(static: "/../..").basename, "/")
        XCTAssertEqual(RelativePath(static: "../..").basename, "..")
        XCTAssertEqual(RelativePath(static: "../a").basename, "a")
        XCTAssertEqual(RelativePath(static: "../a/..").basename, "..")
        XCTAssertEqual(RelativePath(static: "a/..").basename, ".")
        XCTAssertEqual(RelativePath(static: "./..").basename, "..")
        XCTAssertEqual(RelativePath(static: "a/../////../////./////").basename, "..")
        XCTAssertEqual(RelativePath(static: "abc").basename, "abc")
        XCTAssertEqual(RelativePath(static: "").basename, ".")
        XCTAssertEqual(RelativePath(static: ".").basename, ".")
    }

    func testBaseNameWithoutExt() {
        XCTAssertEqual(AbsolutePath(static: "/").basenameWithoutExt, "/")
        XCTAssertEqual(AbsolutePath(static: "/a").basenameWithoutExt, "a")
        XCTAssertEqual(AbsolutePath(static: "/./a").basenameWithoutExt, "a")
        XCTAssertEqual(AbsolutePath(static: "/../..").basenameWithoutExt, "/")
        XCTAssertEqual(RelativePath(static: "../..").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath(static: "../a").basenameWithoutExt, "a")
        XCTAssertEqual(RelativePath(static: "../a/..").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath(static: "a/..").basenameWithoutExt, ".")
        XCTAssertEqual(RelativePath(static: "./..").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath(static: "a/../////../////./////").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath(static: "abc").basenameWithoutExt, "abc")
        XCTAssertEqual(RelativePath(static: "").basenameWithoutExt, ".")
        XCTAssertEqual(RelativePath(static: ".").basenameWithoutExt, ".")

        XCTAssertEqual(AbsolutePath(static: "/a.txt").basenameWithoutExt, "a")
        XCTAssertEqual(AbsolutePath(static: "/./a.txt").basenameWithoutExt, "a")
        XCTAssertEqual(RelativePath(static: "../a.bc").basenameWithoutExt, "a")
        XCTAssertEqual(RelativePath(static: "abc.swift").basenameWithoutExt, "abc")
        XCTAssertEqual(RelativePath(static: "../a.b.c").basenameWithoutExt, "a.b")
        XCTAssertEqual(RelativePath(static: "abc.xyz.123").basenameWithoutExt, "abc.xyz")
    }

    func testSuffixExtraction() {
        XCTAssertEqual(RelativePath(static: "a").suffix, nil)
        XCTAssertEqual(RelativePath(static: "a").extension, nil)
        XCTAssertEqual(RelativePath(static: "a.").suffix, nil)
        XCTAssertEqual(RelativePath(static: "a.").extension, nil)
        XCTAssertEqual(RelativePath(static: ".a").suffix, nil)
        XCTAssertEqual(RelativePath(static: ".a").extension, nil)
        XCTAssertEqual(RelativePath(static: "").suffix, nil)
        XCTAssertEqual(RelativePath(static: "").extension, nil)
        XCTAssertEqual(RelativePath(static: ".").suffix, nil)
        XCTAssertEqual(RelativePath(static: ".").extension, nil)
        XCTAssertEqual(RelativePath(static: "..").suffix, nil)
        XCTAssertEqual(RelativePath(static: "..").extension, nil)
        XCTAssertEqual(RelativePath(static: "a.foo").suffix, ".foo")
        XCTAssertEqual(RelativePath(static: "a.foo").extension, "foo")
        XCTAssertEqual(RelativePath(static: ".a.foo").suffix, ".foo")
        XCTAssertEqual(RelativePath(static: ".a.foo").extension, "foo")
        XCTAssertEqual(RelativePath(static: ".a.foo.bar").suffix, ".bar")
        XCTAssertEqual(RelativePath(static: ".a.foo.bar").extension, "bar")
        XCTAssertEqual(RelativePath(static: "a.foo.bar").suffix, ".bar")
        XCTAssertEqual(RelativePath(static: "a.foo.bar").extension, "bar")
        XCTAssertEqual(RelativePath(static: ".a.foo.bar.baz").suffix, ".baz")
        XCTAssertEqual(RelativePath(static: ".a.foo.bar.baz").extension, "baz")
    }

    func testParentDirectory() {
        XCTAssertEqual(AbsolutePath(static: "/").parentDirectory, AbsolutePath(static: "/"))
        XCTAssertEqual(AbsolutePath(static: "/").parentDirectory.parentDirectory, AbsolutePath(static: "/"))
        XCTAssertEqual(AbsolutePath(static: "/bar").parentDirectory, AbsolutePath(static: "/"))
        XCTAssertEqual(AbsolutePath(static: "/bar/../foo/..//").parentDirectory.parentDirectory, AbsolutePath(static: "/"))
        XCTAssertEqual(AbsolutePath(static: "/bar/../foo/..//yabba/a/b").parentDirectory.parentDirectory, AbsolutePath(static: "/yabba"))
    }

    @available(*, deprecated)
    func testConcatenation() {
        XCTAssertEqual(AbsolutePath(AbsolutePath(static: "/"), RelativePath(static: "")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath(static: "/"), RelativePath(static: ".")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath(static: "/"), RelativePath(static: "..")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath(static: "/"), RelativePath(static: "bar")).pathString, "/bar")
        XCTAssertEqual(AbsolutePath(AbsolutePath(static: "/foo/bar"), RelativePath(static: "..")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath(AbsolutePath(static: "/bar"), RelativePath(static: "../foo")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath(AbsolutePath(static: "/bar"), RelativePath(static: "../foo/..//")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath(static: "/bar/../foo/..//yabba/"), RelativePath(static: "a/b")).pathString, "/yabba/a/b")

        XCTAssertEqual(AbsolutePath(static: "/").appending(RelativePath(static: "")).pathString, "/")
        XCTAssertEqual(AbsolutePath(static: "/").appending(RelativePath(static: ".")).pathString, "/")
        XCTAssertEqual(AbsolutePath(static: "/").appending(RelativePath(static: "..")).pathString, "/")
        XCTAssertEqual(AbsolutePath(static: "/").appending(RelativePath(static: "bar")).pathString, "/bar")
        XCTAssertEqual(AbsolutePath(static: "/foo/bar").appending(RelativePath(static: "..")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath(static: "/bar").appending(RelativePath(static: "../foo")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath(static: "/bar").appending(RelativePath(static: "../foo/..//")).pathString, "/")
        XCTAssertEqual(AbsolutePath(static: "/bar/../foo/..//yabba/").appending(RelativePath(static: "a/b")).pathString, "/yabba/a/b")

        XCTAssertEqual(AbsolutePath(static: "/").appending(component: "a").pathString, "/a")
        XCTAssertEqual(AbsolutePath(static: "/a").appending(component: "b").pathString, "/a/b")
        XCTAssertEqual(AbsolutePath(static: "/").appending(components: "a", "b").pathString, "/a/b")
        XCTAssertEqual(AbsolutePath(static: "/a").appending(components: "b", "c").pathString, "/a/b/c")

        XCTAssertEqual(AbsolutePath(static: "/a/b/c").appending(components: "", "c").pathString, "/a/b/c/c")
        XCTAssertEqual(AbsolutePath(static: "/a/b/c").appending(components: "").pathString, "/a/b/c")
        XCTAssertEqual(AbsolutePath(static: "/a/b/c").appending(components: ".").pathString, "/a/b/c")
        XCTAssertEqual(AbsolutePath(static: "/a/b/c").appending(components: "..").pathString, "/a/b")
        XCTAssertEqual(AbsolutePath(static: "/a/b/c").appending(components: "..", "d").pathString, "/a/b/d")
        XCTAssertEqual(AbsolutePath(static: "/").appending(components: "..").pathString, "/")
        XCTAssertEqual(AbsolutePath(static: "/").appending(components: ".").pathString, "/")
        XCTAssertEqual(AbsolutePath(static: "/").appending(components: "..", "a").pathString, "/a")

        XCTAssertEqual(RelativePath(static: "hello").appending(components: "a", "b", "c", "..").pathString, "hello/a/b")
        XCTAssertEqual(RelativePath(static: "hello").appending(RelativePath(static: "a/b/../c/d")).pathString, "hello/a/c/d")
    }

    func testPathComponents() {
        XCTAssertEqual(AbsolutePath(static: "/").components, ["/"])
        XCTAssertEqual(AbsolutePath(static: "/.").components, ["/"])
        XCTAssertEqual(AbsolutePath(static: "/..").components, ["/"])
        XCTAssertEqual(AbsolutePath(static: "/bar").components, ["/", "bar"])
        XCTAssertEqual(AbsolutePath(static: "/foo/bar/..").components, ["/", "foo"])
        XCTAssertEqual(AbsolutePath(static: "/bar/../foo").components, ["/", "foo"])
        XCTAssertEqual(AbsolutePath(static: "/bar/../foo/..//").components, ["/"])
        XCTAssertEqual(AbsolutePath(static: "/bar/../foo/..//yabba/a/b/").components, ["/", "yabba", "a", "b"])

        XCTAssertEqual(RelativePath(static: "").components, ["."])
        XCTAssertEqual(RelativePath(static: ".").components, ["."])
        XCTAssertEqual(RelativePath(static: "..").components, [".."])
        XCTAssertEqual(RelativePath(static: "bar").components, ["bar"])
        XCTAssertEqual(RelativePath(static: "foo/bar/..").components, ["foo"])
        XCTAssertEqual(RelativePath(static: "bar/../foo").components, ["foo"])
        XCTAssertEqual(RelativePath(static: "bar/../foo/..//").components, ["."])
        XCTAssertEqual(RelativePath(static: "bar/../foo/..//yabba/a/b/").components, ["yabba", "a", "b"])
        XCTAssertEqual(RelativePath(static: "../..").components, ["..", ".."])
        XCTAssertEqual(RelativePath(static: ".././/..").components, ["..", ".."])
        XCTAssertEqual(RelativePath(static: "../a").components, ["..", "a"])
        XCTAssertEqual(RelativePath(static: "../a/..").components, [".."])
        XCTAssertEqual(RelativePath(static: "a/..").components, ["."])
        XCTAssertEqual(RelativePath(static: "./..").components, [".."])
        XCTAssertEqual(RelativePath(static: "a/../////../////./////").components, [".."])
        XCTAssertEqual(RelativePath(static: "abc").components, ["abc"])
    }

    func testRelativePathFromAbsolutePaths() {
        XCTAssertEqual(AbsolutePath(static: "/").relative(to: AbsolutePath(static: "/")), RelativePath(static: "."));
        XCTAssertEqual(AbsolutePath(static: "/a/b/c/d").relative(to: AbsolutePath(static: "/")), RelativePath(static: "a/b/c/d"));
        XCTAssertEqual(AbsolutePath(static: "/").relative(to: AbsolutePath(static: "/a/b/c")), RelativePath(static: "../../.."));
        XCTAssertEqual(AbsolutePath(static: "/a/b/c/d").relative(to: AbsolutePath(static: "/a/b")), RelativePath(static: "c/d"));
        XCTAssertEqual(AbsolutePath(static: "/a/b/c/d").relative(to: AbsolutePath(static: "/a/b/c")), RelativePath(static: "d"));
        XCTAssertEqual(AbsolutePath(static: "/a/b/c/d").relative(to: AbsolutePath(static: "/a/c/d")), RelativePath(static: "../../b/c/d"));
        XCTAssertEqual(AbsolutePath(static: "/a/b/c/d").relative(to: AbsolutePath(static: "/b/c/d")), RelativePath(static: "../../../a/b/c/d"));
    }

    func testComparison() {
        XCTAssertTrue(AbsolutePath(static: "/") <= AbsolutePath(static: "/"));
        XCTAssertTrue(AbsolutePath(static: "/abc") < AbsolutePath(static: "/def"));
        XCTAssertTrue(AbsolutePath(static: "/2") <= AbsolutePath(static: "/2.1"));
        XCTAssertTrue(AbsolutePath(static: "/3.1") > AbsolutePath(static: "/2"));
        XCTAssertTrue(AbsolutePath(static: "/2") >= AbsolutePath(static: "/2"));
        XCTAssertTrue(AbsolutePath(static: "/2.1") >= AbsolutePath(static: "/2"));
    }

    func testAncestry() {
        XCTAssertTrue(AbsolutePath(static: "/a/b/c/d/e/f").isDescendantOfOrEqual(to: AbsolutePath(static: "/a/b/c/d")))
        XCTAssertTrue(AbsolutePath(static: "/a/b/c/d/e/f.swift").isDescendantOfOrEqual(to: AbsolutePath(static: "/a/b/c")))
        XCTAssertTrue(AbsolutePath(static: "/").isDescendantOfOrEqual(to: AbsolutePath(static: "/")))
        XCTAssertTrue(AbsolutePath(static: "/foo/bar").isDescendantOfOrEqual(to: AbsolutePath(static: "/")))
        XCTAssertFalse(AbsolutePath(static: "/foo/bar").isDescendantOfOrEqual(to: AbsolutePath(static: "/foo/bar/baz")))
        XCTAssertFalse(AbsolutePath(static: "/foo/bar").isDescendantOfOrEqual(to: AbsolutePath(static: "/bar")))

        XCTAssertFalse(AbsolutePath(static: "/foo/bar").isDescendant(of: AbsolutePath(static: "/foo/bar")))
        XCTAssertTrue(AbsolutePath(static: "/foo/bar").isDescendant(of: AbsolutePath(static: "/foo")))

        XCTAssertTrue(AbsolutePath(static: "/a/b/c/d").isAncestorOfOrEqual(to: AbsolutePath(static: "/a/b/c/d/e/f")))
        XCTAssertTrue(AbsolutePath(static: "/a/b/c").isAncestorOfOrEqual(to: AbsolutePath(static: "/a/b/c/d/e/f.swift")))
        XCTAssertTrue(AbsolutePath(static: "/").isAncestorOfOrEqual(to: AbsolutePath(static: "/")))
        XCTAssertTrue(AbsolutePath(static: "/").isAncestorOfOrEqual(to: AbsolutePath(static: "/foo/bar")))
        XCTAssertFalse(AbsolutePath(static: "/foo/bar/baz").isAncestorOfOrEqual(to: AbsolutePath(static: "/foo/bar")))
        XCTAssertFalse(AbsolutePath(static: "/bar").isAncestorOfOrEqual(to: AbsolutePath(static: "/foo/bar")))

        XCTAssertFalse(AbsolutePath(static: "/foo/bar").isAncestor(of: AbsolutePath(static: "/foo/bar")))
        XCTAssertTrue(AbsolutePath(static: "/foo").isAncestor(of: AbsolutePath(static: "/foo/bar")))
    }

    func testAbsolutePathValidation() {
        XCTAssertNoThrow(try AbsolutePath(validating: "/a/b/c/d"))

        XCTAssertThrowsError(try AbsolutePath(validating: "~/a/b/d")) { error in
            XCTAssertEqual("\(error)", "invalid absolute path '~/a/b/d'; absolute path must begin with '/'")
        }

        XCTAssertThrowsError(try AbsolutePath(validating: "a/b/d")) { error in
            XCTAssertEqual("\(error)", "invalid absolute path 'a/b/d'")
        }
    }

    func testRelativePathValidation() {
        XCTAssertNoThrow(try RelativePath(validating: "a/b/c/d"))

        XCTAssertThrowsError(try RelativePath(validating: "/a/b/d")) { error in
            XCTAssertEqual("\(error)", "invalid relative path '/a/b/d'; relative path should not begin with '/'")
            //XCTAssertEqual("\(error)", "invalid relative path '/a/b/d'; relative path should not begin with '/' or '~'")
        }

        /*XCTAssertThrowsError(try RelativePath(validating: "~/a/b/d")) { error in
            XCTAssertEqual("\(error)", "invalid relative path '~/a/b/d'; relative path should not begin with '/' or '~'")
        }*/
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
            let foo = Foo(path: AbsolutePath(static: "/path/to/foo"))
            let data = try JSONEncoder().encode(foo)
            let decodedFoo = try JSONDecoder().decode(Foo.self, from: data)
            XCTAssertEqual(foo, decodedFoo)
        }

        do {
            let foo = Foo(path: AbsolutePath(static: "/path/to/../to/foo"))
            let data = try JSONEncoder().encode(foo)
            let decodedFoo = try JSONDecoder().decode(Foo.self, from: data)
            XCTAssertEqual(foo, decodedFoo)
            XCTAssertEqual(foo.path.pathString, "/path/to/foo")
            XCTAssertEqual(decodedFoo.path.pathString, "/path/to/foo")
        }

        do {
            let bar = Bar(path: RelativePath(static: "path/to/bar"))
            let data = try JSONEncoder().encode(bar)
            let decodedBar = try JSONDecoder().decode(Bar.self, from: data)
            XCTAssertEqual(bar, decodedBar)
        }

        do {
            let bar = Bar(path: RelativePath(static: "path/to/../to/bar"))
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
