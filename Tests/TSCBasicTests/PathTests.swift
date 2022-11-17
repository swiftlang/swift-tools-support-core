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
        XCTAssertEqual(AbsolutePath(path: "/").pathString, "/")
        XCTAssertEqual(AbsolutePath(path: "/a").pathString, "/a")
        XCTAssertEqual(AbsolutePath(path: "/a/b/c").pathString, "/a/b/c")
        XCTAssertEqual(RelativePath(path: ".").pathString, ".")
        XCTAssertEqual(RelativePath(path: "a").pathString, "a")
        XCTAssertEqual(RelativePath(path: "a/b/c").pathString, "a/b/c")
        //XCTAssertEqual(RelativePath(path: "~").pathString, "~")  // `~` is not special
    }

    func testStringInitialization() throws {
        let abs1 = AbsolutePath(path: "/")
        let abs2 = AbsolutePath(base: abs1, ".")
        XCTAssertEqual(abs1, abs2)
        let rel3 = "."
        let abs3 = try AbsolutePath(abs2, rel3)
        XCTAssertEqual(abs2, abs3)
        let base = AbsolutePath(path: "/base/path")
        let abs4 = AbsolutePath(path: "/a/b/c", relativeTo: base)
        XCTAssertEqual(abs4, AbsolutePath(path: "/a/b/c"))
        let abs5 = AbsolutePath(path: "./a/b/c", relativeTo: base)
        XCTAssertEqual(abs5, AbsolutePath(path: "/base/path/a/b/c"))
        //let abs6 = AbsolutePath(path: "~/bla", relativeTo: base)  // `~` isn't special
        //XCTAssertEqual(abs6, AbsolutePath(path: "/base/path/~/bla"))
    }

    func testStringLiteralInitialization() {
        let abs = AbsolutePath(path: "/")
        XCTAssertEqual(abs.pathString, "/")
        let rel1 = RelativePath(path: ".")
        XCTAssertEqual(rel1.pathString, ".")
        //let rel2 = RelativePath(path: "~")
        //XCTAssertEqual(rel2.pathString, "~")  // `~` is not special
    }

    func testRepeatedPathSeparators() {
        XCTAssertEqual(AbsolutePath(path: "/ab//cd//ef").pathString, "/ab/cd/ef")
        XCTAssertEqual(AbsolutePath(path: "/ab///cd//ef").pathString, "/ab/cd/ef")
        XCTAssertEqual(RelativePath(path: "ab//cd//ef").pathString, "ab/cd/ef")
        XCTAssertEqual(RelativePath(path: "ab//cd///ef").pathString, "ab/cd/ef")
    }

    func testTrailingPathSeparators() {
        XCTAssertEqual(AbsolutePath(path: "/ab/cd/ef/").pathString, "/ab/cd/ef")
        XCTAssertEqual(AbsolutePath(path: "/ab/cd/ef//").pathString, "/ab/cd/ef")
        XCTAssertEqual(RelativePath(path: "ab/cd/ef/").pathString, "ab/cd/ef")
        XCTAssertEqual(RelativePath(path: "ab/cd/ef//").pathString, "ab/cd/ef")
    }

    func testDotPathComponents() {
        XCTAssertEqual(AbsolutePath(path: "/ab/././cd//ef").pathString, "/ab/cd/ef")
        XCTAssertEqual(AbsolutePath(path: "/ab/./cd//ef/.").pathString, "/ab/cd/ef")
        XCTAssertEqual(RelativePath(path: "ab/./cd/././ef").pathString, "ab/cd/ef")
        XCTAssertEqual(RelativePath(path: "ab/./cd/ef/.").pathString, "ab/cd/ef")
    }

    func testDotDotPathComponents() {
        XCTAssertEqual(AbsolutePath(path: "/..").pathString, "/")
        XCTAssertEqual(AbsolutePath(path: "/../../../../..").pathString, "/")
        XCTAssertEqual(AbsolutePath(path: "/abc/..").pathString, "/")
        XCTAssertEqual(AbsolutePath(path: "/abc/../..").pathString, "/")
        XCTAssertEqual(AbsolutePath(path: "/../abc").pathString, "/abc")
        XCTAssertEqual(AbsolutePath(path: "/../abc/..").pathString, "/")
        XCTAssertEqual(AbsolutePath(path: "/../abc/../def").pathString, "/def")
        XCTAssertEqual(RelativePath(path: "..").pathString, "..")
        XCTAssertEqual(RelativePath(path: "../..").pathString, "../..")
        XCTAssertEqual(RelativePath(path: ".././..").pathString, "../..")
        XCTAssertEqual(RelativePath(path: "../abc/..").pathString, "..")
        XCTAssertEqual(RelativePath(path: "../abc/.././").pathString, "..")
        XCTAssertEqual(RelativePath(path: "abc/..").pathString, ".")
    }

    func testCombinationsAndEdgeCases() {
        XCTAssertEqual(AbsolutePath(path: "///").pathString, "/")
        XCTAssertEqual(AbsolutePath(path: "/./").pathString, "/")
        XCTAssertEqual(RelativePath(path: "").pathString, ".")
        XCTAssertEqual(RelativePath(path: ".").pathString, ".")
        XCTAssertEqual(RelativePath(path: "./abc").pathString, "abc")
        XCTAssertEqual(RelativePath(path: "./abc/").pathString, "abc")
        XCTAssertEqual(RelativePath(path: "./abc/../bar").pathString, "bar")
        XCTAssertEqual(RelativePath(path: "foo/../bar").pathString, "bar")
        XCTAssertEqual(RelativePath(path: "foo///..///bar///baz").pathString, "bar/baz")
        XCTAssertEqual(RelativePath(path: "foo/../bar/./").pathString, "bar")
        XCTAssertEqual(RelativePath(path: "../abc/def/").pathString, "../abc/def")
        XCTAssertEqual(RelativePath(path: "././././.").pathString, ".")
        XCTAssertEqual(RelativePath(path: "./././../.").pathString, "..")
        XCTAssertEqual(RelativePath(path: "./").pathString, ".")
        XCTAssertEqual(RelativePath(path: ".//").pathString, ".")
        XCTAssertEqual(RelativePath(path: "./.").pathString, ".")
        XCTAssertEqual(RelativePath(path: "././").pathString, ".")
        XCTAssertEqual(RelativePath(path: "../").pathString, "..")
        XCTAssertEqual(RelativePath(path: "../.").pathString, "..")
        XCTAssertEqual(RelativePath(path: "./..").pathString, "..")
        XCTAssertEqual(RelativePath(path: "./../.").pathString, "..")
        XCTAssertEqual(RelativePath(path: "./////../////./////").pathString, "..")
        XCTAssertEqual(RelativePath(path: "../a").pathString, "../a")
        XCTAssertEqual(RelativePath(path: "../a/..").pathString, "..")
        XCTAssertEqual(RelativePath(path: "a/..").pathString, ".")
        XCTAssertEqual(RelativePath(path: "a/../////../////./////").pathString, "..")
    }

    func testDirectoryNameExtraction() {
        XCTAssertEqual(AbsolutePath(path: "/").dirname, "/")
        XCTAssertEqual(AbsolutePath(path: "/a").dirname, "/")
        XCTAssertEqual(AbsolutePath(path: "/./a").dirname, "/")
        XCTAssertEqual(AbsolutePath(path: "/../..").dirname, "/")
        XCTAssertEqual(AbsolutePath(path: "/ab/c//d/").dirname, "/ab/c")
        XCTAssertEqual(RelativePath(path: "ab/c//d/").dirname, "ab/c")
        XCTAssertEqual(RelativePath(path: "../a").dirname, "..")
        XCTAssertEqual(RelativePath(path: "../a/..").dirname, ".")
        XCTAssertEqual(RelativePath(path: "a/..").dirname, ".")
        XCTAssertEqual(RelativePath(path: "./..").dirname, ".")
        XCTAssertEqual(RelativePath(path: "a/../////../////./////").dirname, ".")
        XCTAssertEqual(RelativePath(path: "abc").dirname, ".")
        XCTAssertEqual(RelativePath(path: "").dirname, ".")
        XCTAssertEqual(RelativePath(path: ".").dirname, ".")
    }

    func testBaseNameExtraction() {
        XCTAssertEqual(AbsolutePath(path: "/").basename, "/")
        XCTAssertEqual(AbsolutePath(path: "/a").basename, "a")
        XCTAssertEqual(AbsolutePath(path: "/./a").basename, "a")
        XCTAssertEqual(AbsolutePath(path: "/../..").basename, "/")
        XCTAssertEqual(RelativePath(path: "../..").basename, "..")
        XCTAssertEqual(RelativePath(path: "../a").basename, "a")
        XCTAssertEqual(RelativePath(path: "../a/..").basename, "..")
        XCTAssertEqual(RelativePath(path: "a/..").basename, ".")
        XCTAssertEqual(RelativePath(path: "./..").basename, "..")
        XCTAssertEqual(RelativePath(path: "a/../////../////./////").basename, "..")
        XCTAssertEqual(RelativePath(path: "abc").basename, "abc")
        XCTAssertEqual(RelativePath(path: "").basename, ".")
        XCTAssertEqual(RelativePath(path: ".").basename, ".")
    }

    func testBaseNameWithoutExt() {
        XCTAssertEqual(AbsolutePath(path: "/").basenameWithoutExt, "/")
        XCTAssertEqual(AbsolutePath(path: "/a").basenameWithoutExt, "a")
        XCTAssertEqual(AbsolutePath(path: "/./a").basenameWithoutExt, "a")
        XCTAssertEqual(AbsolutePath(path: "/../..").basenameWithoutExt, "/")
        XCTAssertEqual(RelativePath(path: "../..").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath(path: "../a").basenameWithoutExt, "a")
        XCTAssertEqual(RelativePath(path: "../a/..").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath(path: "a/..").basenameWithoutExt, ".")
        XCTAssertEqual(RelativePath(path: "./..").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath(path: "a/../////../////./////").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath(path: "abc").basenameWithoutExt, "abc")
        XCTAssertEqual(RelativePath(path: "").basenameWithoutExt, ".")
        XCTAssertEqual(RelativePath(path: ".").basenameWithoutExt, ".")

        XCTAssertEqual(AbsolutePath(path: "/a.txt").basenameWithoutExt, "a")
        XCTAssertEqual(AbsolutePath(path: "/./a.txt").basenameWithoutExt, "a")
        XCTAssertEqual(RelativePath(path: "../a.bc").basenameWithoutExt, "a")
        XCTAssertEqual(RelativePath(path: "abc.swift").basenameWithoutExt, "abc")
        XCTAssertEqual(RelativePath(path: "../a.b.c").basenameWithoutExt, "a.b")
        XCTAssertEqual(RelativePath(path: "abc.xyz.123").basenameWithoutExt, "abc.xyz")
    }

    func testSuffixExtraction() {
        XCTAssertEqual(RelativePath(path: "a").suffix, nil)
        XCTAssertEqual(RelativePath(path: "a").extension, nil)
        XCTAssertEqual(RelativePath(path: "a.").suffix, nil)
        XCTAssertEqual(RelativePath(path: "a.").extension, nil)
        XCTAssertEqual(RelativePath(path: ".a").suffix, nil)
        XCTAssertEqual(RelativePath(path: ".a").extension, nil)
        XCTAssertEqual(RelativePath(path: "").suffix, nil)
        XCTAssertEqual(RelativePath(path: "").extension, nil)
        XCTAssertEqual(RelativePath(path: ".").suffix, nil)
        XCTAssertEqual(RelativePath(path: ".").extension, nil)
        XCTAssertEqual(RelativePath(path: "..").suffix, nil)
        XCTAssertEqual(RelativePath(path: "..").extension, nil)
        XCTAssertEqual(RelativePath(path: "a.foo").suffix, ".foo")
        XCTAssertEqual(RelativePath(path: "a.foo").extension, "foo")
        XCTAssertEqual(RelativePath(path: ".a.foo").suffix, ".foo")
        XCTAssertEqual(RelativePath(path: ".a.foo").extension, "foo")
        XCTAssertEqual(RelativePath(path: ".a.foo.bar").suffix, ".bar")
        XCTAssertEqual(RelativePath(path: ".a.foo.bar").extension, "bar")
        XCTAssertEqual(RelativePath(path: "a.foo.bar").suffix, ".bar")
        XCTAssertEqual(RelativePath(path: "a.foo.bar").extension, "bar")
        XCTAssertEqual(RelativePath(path: ".a.foo.bar.baz").suffix, ".baz")
        XCTAssertEqual(RelativePath(path: ".a.foo.bar.baz").extension, "baz")
    }

    func testParentDirectory() {
        XCTAssertEqual(AbsolutePath(path: "/").parentDirectory, AbsolutePath(path: "/"))
        XCTAssertEqual(AbsolutePath(path: "/").parentDirectory.parentDirectory, AbsolutePath(path: "/"))
        XCTAssertEqual(AbsolutePath(path: "/bar").parentDirectory, AbsolutePath(path: "/"))
        XCTAssertEqual(AbsolutePath(path: "/bar/../foo/..//").parentDirectory.parentDirectory, AbsolutePath(path: "/"))
        XCTAssertEqual(AbsolutePath(path: "/bar/../foo/..//yabba/a/b").parentDirectory.parentDirectory, AbsolutePath(path: "/yabba"))
    }

    @available(*, deprecated)
    func testConcatenation() {
        XCTAssertEqual(AbsolutePath(AbsolutePath(path: "/"), RelativePath(path: "")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath(path: "/"), RelativePath(path: ".")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath(path: "/"), RelativePath(path: "..")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath(path: "/"), RelativePath(path: "bar")).pathString, "/bar")
        XCTAssertEqual(AbsolutePath(AbsolutePath(path: "/foo/bar"), RelativePath(path: "..")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath(AbsolutePath(path: "/bar"), RelativePath(path: "../foo")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath(AbsolutePath(path: "/bar"), RelativePath(path: "../foo/..//")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath(path: "/bar/../foo/..//yabba/"), RelativePath(path: "a/b")).pathString, "/yabba/a/b")

        XCTAssertEqual(AbsolutePath(path: "/").appending(RelativePath(path: "")).pathString, "/")
        XCTAssertEqual(AbsolutePath(path: "/").appending(RelativePath(path: ".")).pathString, "/")
        XCTAssertEqual(AbsolutePath(path: "/").appending(RelativePath(path: "..")).pathString, "/")
        XCTAssertEqual(AbsolutePath(path: "/").appending(RelativePath(path: "bar")).pathString, "/bar")
        XCTAssertEqual(AbsolutePath(path: "/foo/bar").appending(RelativePath(path: "..")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath(path: "/bar").appending(RelativePath(path: "../foo")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath(path: "/bar").appending(RelativePath(path: "../foo/..//")).pathString, "/")
        XCTAssertEqual(AbsolutePath(path: "/bar/../foo/..//yabba/").appending(RelativePath(path: "a/b")).pathString, "/yabba/a/b")

        XCTAssertEqual(AbsolutePath(path: "/").appending(component: "a").pathString, "/a")
        XCTAssertEqual(AbsolutePath(path: "/a").appending(component: "b").pathString, "/a/b")
        XCTAssertEqual(AbsolutePath(path: "/").appending(components: "a", "b").pathString, "/a/b")
        XCTAssertEqual(AbsolutePath(path: "/a").appending(components: "b", "c").pathString, "/a/b/c")

        XCTAssertEqual(AbsolutePath(path: "/a/b/c").appending(components: "", "c").pathString, "/a/b/c/c")
        XCTAssertEqual(AbsolutePath(path: "/a/b/c").appending(components: "").pathString, "/a/b/c")
        XCTAssertEqual(AbsolutePath(path: "/a/b/c").appending(components: ".").pathString, "/a/b/c")
        XCTAssertEqual(AbsolutePath(path: "/a/b/c").appending(components: "..").pathString, "/a/b")
        XCTAssertEqual(AbsolutePath(path: "/a/b/c").appending(components: "..", "d").pathString, "/a/b/d")
        XCTAssertEqual(AbsolutePath(path: "/").appending(components: "..").pathString, "/")
        XCTAssertEqual(AbsolutePath(path: "/").appending(components: ".").pathString, "/")
        XCTAssertEqual(AbsolutePath(path: "/").appending(components: "..", "a").pathString, "/a")

        XCTAssertEqual(RelativePath(path: "hello").appending(components: "a", "b", "c", "..").pathString, "hello/a/b")
        XCTAssertEqual(RelativePath(path: "hello").appending(RelativePath(path: "a/b/../c/d")).pathString, "hello/a/c/d")
    }

    func testPathComponents() {
        XCTAssertEqual(AbsolutePath(path: "/").components, ["/"])
        XCTAssertEqual(AbsolutePath(path: "/.").components, ["/"])
        XCTAssertEqual(AbsolutePath(path: "/..").components, ["/"])
        XCTAssertEqual(AbsolutePath(path: "/bar").components, ["/", "bar"])
        XCTAssertEqual(AbsolutePath(path: "/foo/bar/..").components, ["/", "foo"])
        XCTAssertEqual(AbsolutePath(path: "/bar/../foo").components, ["/", "foo"])
        XCTAssertEqual(AbsolutePath(path: "/bar/../foo/..//").components, ["/"])
        XCTAssertEqual(AbsolutePath(path: "/bar/../foo/..//yabba/a/b/").components, ["/", "yabba", "a", "b"])

        XCTAssertEqual(RelativePath(path: "").components, ["."])
        XCTAssertEqual(RelativePath(path: ".").components, ["."])
        XCTAssertEqual(RelativePath(path: "..").components, [".."])
        XCTAssertEqual(RelativePath(path: "bar").components, ["bar"])
        XCTAssertEqual(RelativePath(path: "foo/bar/..").components, ["foo"])
        XCTAssertEqual(RelativePath(path: "bar/../foo").components, ["foo"])
        XCTAssertEqual(RelativePath(path: "bar/../foo/..//").components, ["."])
        XCTAssertEqual(RelativePath(path: "bar/../foo/..//yabba/a/b/").components, ["yabba", "a", "b"])
        XCTAssertEqual(RelativePath(path: "../..").components, ["..", ".."])
        XCTAssertEqual(RelativePath(path: ".././/..").components, ["..", ".."])
        XCTAssertEqual(RelativePath(path: "../a").components, ["..", "a"])
        XCTAssertEqual(RelativePath(path: "../a/..").components, [".."])
        XCTAssertEqual(RelativePath(path: "a/..").components, ["."])
        XCTAssertEqual(RelativePath(path: "./..").components, [".."])
        XCTAssertEqual(RelativePath(path: "a/../////../////./////").components, [".."])
        XCTAssertEqual(RelativePath(path: "abc").components, ["abc"])
    }

    func testRelativePathFromAbsolutePaths() {
        XCTAssertEqual(AbsolutePath(path: "/").relative(to: AbsolutePath(path: "/")), RelativePath(path: "."));
        XCTAssertEqual(AbsolutePath(path: "/a/b/c/d").relative(to: AbsolutePath(path: "/")), RelativePath(path: "a/b/c/d"));
        XCTAssertEqual(AbsolutePath(path: "/").relative(to: AbsolutePath(path: "/a/b/c")), RelativePath(path: "../../.."));
        XCTAssertEqual(AbsolutePath(path: "/a/b/c/d").relative(to: AbsolutePath(path: "/a/b")), RelativePath(path: "c/d"));
        XCTAssertEqual(AbsolutePath(path: "/a/b/c/d").relative(to: AbsolutePath(path: "/a/b/c")), RelativePath(path: "d"));
        XCTAssertEqual(AbsolutePath(path: "/a/b/c/d").relative(to: AbsolutePath(path: "/a/c/d")), RelativePath(path: "../../b/c/d"));
        XCTAssertEqual(AbsolutePath(path: "/a/b/c/d").relative(to: AbsolutePath(path: "/b/c/d")), RelativePath(path: "../../../a/b/c/d"));
    }

    func testComparison() {
        XCTAssertTrue(AbsolutePath(path: "/") <= AbsolutePath(path: "/"));
        XCTAssertTrue(AbsolutePath(path: "/abc") < AbsolutePath(path: "/def"));
        XCTAssertTrue(AbsolutePath(path: "/2") <= AbsolutePath(path: "/2.1"));
        XCTAssertTrue(AbsolutePath(path: "/3.1") > AbsolutePath(path: "/2"));
        XCTAssertTrue(AbsolutePath(path: "/2") >= AbsolutePath(path: "/2"));
        XCTAssertTrue(AbsolutePath(path: "/2.1") >= AbsolutePath(path: "/2"));
    }

    func testAncestry() {
        XCTAssertTrue(AbsolutePath(path: "/a/b/c/d/e/f").isDescendantOfOrEqual(to: AbsolutePath(path: "/a/b/c/d")))
        XCTAssertTrue(AbsolutePath(path: "/a/b/c/d/e/f.swift").isDescendantOfOrEqual(to: AbsolutePath(path: "/a/b/c")))
        XCTAssertTrue(AbsolutePath(path: "/").isDescendantOfOrEqual(to: AbsolutePath(path: "/")))
        XCTAssertTrue(AbsolutePath(path: "/foo/bar").isDescendantOfOrEqual(to: AbsolutePath(path: "/")))
        XCTAssertFalse(AbsolutePath(path: "/foo/bar").isDescendantOfOrEqual(to: AbsolutePath(path: "/foo/bar/baz")))
        XCTAssertFalse(AbsolutePath(path: "/foo/bar").isDescendantOfOrEqual(to: AbsolutePath(path: "/bar")))

        XCTAssertFalse(AbsolutePath(path: "/foo/bar").isDescendant(of: AbsolutePath(path: "/foo/bar")))
        XCTAssertTrue(AbsolutePath(path: "/foo/bar").isDescendant(of: AbsolutePath(path: "/foo")))

        XCTAssertTrue(AbsolutePath(path: "/a/b/c/d").isAncestorOfOrEqual(to: AbsolutePath(path: "/a/b/c/d/e/f")))
        XCTAssertTrue(AbsolutePath(path: "/a/b/c").isAncestorOfOrEqual(to: AbsolutePath(path: "/a/b/c/d/e/f.swift")))
        XCTAssertTrue(AbsolutePath(path: "/").isAncestorOfOrEqual(to: AbsolutePath(path: "/")))
        XCTAssertTrue(AbsolutePath(path: "/").isAncestorOfOrEqual(to: AbsolutePath(path: "/foo/bar")))
        XCTAssertFalse(AbsolutePath(path: "/foo/bar/baz").isAncestorOfOrEqual(to: AbsolutePath(path: "/foo/bar")))
        XCTAssertFalse(AbsolutePath(path: "/bar").isAncestorOfOrEqual(to: AbsolutePath(path: "/foo/bar")))

        XCTAssertFalse(AbsolutePath(path: "/foo/bar").isAncestor(of: AbsolutePath(path: "/foo/bar")))
        XCTAssertTrue(AbsolutePath(path: "/foo").isAncestor(of: AbsolutePath(path: "/foo/bar")))
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
            XCTAssertEqual("\(error)", "invalid relative path '/a/b/d'; relative path should not begin with '/' or '~'")
        }

        XCTAssertThrowsError(try RelativePath(validating: "~/a/b/d")) { error in
            XCTAssertEqual("\(error)", "invalid relative path '~/a/b/d'; relative path should not begin with '/' or '~'")
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
            let foo = Foo(path: AbsolutePath(path: "/path/to/foo"))
            let data = try JSONEncoder().encode(foo)
            let decodedFoo = try JSONDecoder().decode(Foo.self, from: data)
            XCTAssertEqual(foo, decodedFoo)
        }

        do {
            let foo = Foo(path: AbsolutePath(path: "/path/to/../to/foo"))
            let data = try JSONEncoder().encode(foo)
            let decodedFoo = try JSONDecoder().decode(Foo.self, from: data)
            XCTAssertEqual(foo, decodedFoo)
            XCTAssertEqual(foo.path.pathString, "/path/to/foo")
            XCTAssertEqual(decodedFoo.path.pathString, "/path/to/foo")
        }

        do {
            let bar = Bar(path: RelativePath(path: "path/to/bar"))
            let data = try JSONEncoder().encode(bar)
            let decodedBar = try JSONDecoder().decode(Bar.self, from: data)
            XCTAssertEqual(bar, decodedBar)
        }

        do {
            let bar = Bar(path: RelativePath(path: "path/to/../to/bar"))
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
