/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import Foundation
import TSCBasic
import TSCTestSupport
import XCTest

func generatePath(_ length: Int, absolute: Bool = true, duplicateSeparators: Bool = false, useUnparsedPrefix: Bool=false, useDevicePrefix: Bool=false) -> String {
    #if !os(Windows)
    var path = absolute ? "/" : ""
    let separator = duplicateSeparators ? "//" : "/"
    #else
    var path = absolute ? #"C:"# : ""
    if useUnparsedPrefix && !useDevicePrefix {
        path = #"\\?\"# + path
    }
    if useDevicePrefix && !useUnparsedPrefix {
        path = #"\\.\"# + path
    }
    let separator = duplicateSeparators ? #"\\"# : #"\"#
    #endif
    var currentPathLength = path.count
    var dirNameCount = 0
    while currentPathLength < length {
        let dirName = String(dirNameCount)
        assert(!(dirName.count > 255), "Path component of \(dirName) exceeds 255 characters") // Windows has path component limits of 255
        path.append("\(path.count != 0 ? separator : "")\(dirName)")
        dirNameCount += 1
        currentPathLength += separator.count + dirName.count
    }
    return path
}

class PathTests: XCTestCase {
    // The implementation of RelativePath on Windows does not do any path canonicalization/normalization".
    // Canonicalization is only done on AbsolutePaths, so all tests need to handle this difference.

    func testBasics() {
        #if !os(Windows)
        XCTAssertEqual(AbsolutePath("/").pathString, "/")
        XCTAssertEqual(AbsolutePath("/a").pathString, "/a")
        XCTAssertEqual(AbsolutePath("/a/b/c").pathString, "/a/b/c")
        XCTAssertEqual(RelativePath(".").pathString, ".")
        XCTAssertEqual(RelativePath("a").pathString, "a")
        XCTAssertEqual(RelativePath("a/b/c").pathString, "a/b/c")
        XCTAssertEqual(RelativePath("~").pathString, "~") // `~` is not special
        #else
        // Backslash is considered an absolute path by 'PathIsRelativeW', however after canonicalization the drive designator
        // of current working drive will be added to the path.
        XCTAssert(try #/[A-Z]:\\/#.wholeMatch(in: AbsolutePath(#"\"#).pathString) != nil)
        XCTAssert(try #/[A-Z]:\\foo/#.wholeMatch(in: AbsolutePath(#"\foo"#).pathString) != nil)
        XCTAssertEqual(AbsolutePath(#"C:\"#).pathString, #"C:\"#)
        XCTAssertEqual(RelativePath(".").pathString, ".")
        XCTAssertEqual(RelativePath("a").pathString, "a")
        XCTAssertEqual(RelativePath(#"a\b\c"#).pathString, #"a\b\c"#)

        // Unparsed prefix '\\?\'' < PATH_MAX
        XCTAssertEqual(AbsolutePath(#"\\?\C:\"#).pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"\\?\C:"#).pathString, #"C:\"#)
        XCTAssert(try #/[A-Z]:foo/#.wholeMatch(in: AbsolutePath(#"\\?\C:foo"#).pathString) != nil, "Got: \(AbsolutePath(#"\\?\C:foo"#).pathString)")
        XCTAssert(try #/[A-Z]:\\foo/#.wholeMatch(in: AbsolutePath(#"\\?\C:\foo"#).pathString) != nil, "Got: \(AbsolutePath(#"\\?\C:\foo"#).pathString)")

        // Unparsed prefix > PATH_MAX
        let longAbsolutePathUnderPathMax = generatePath(200)
        XCTAssertEqual(AbsolutePath(longAbsolutePathUnderPathMax).pathString, longAbsolutePathUnderPathMax)
        let longAbsolutePathOverPathMax = generatePath(260)
        XCTAssertEqual(AbsolutePath(longAbsolutePathOverPathMax).pathString, #"\\?\"# + longAbsolutePathOverPathMax)
        let unParsedLongAbsolutePathUnderPathMax = generatePath(265, useUnparsedPrefix: true)
        XCTAssertEqual(AbsolutePath(unParsedLongAbsolutePathUnderPathMax).pathString, unParsedLongAbsolutePathUnderPathMax)

        // Device prefix < PATH_MAX
        XCTAssertEqual(AbsolutePath(#"\\.\C:\"#).pathString, #"\\.\C:"#)
        XCTAssertEqual(AbsolutePath(#"\\.\C:\foo"#).pathString, #"\\.\C:\foo"#)
        let deviceLongAbsolutePathUnderPathMax = generatePath(265, useDevicePrefix: true)
        XCTAssertEqual(AbsolutePath(deviceLongAbsolutePathUnderPathMax).pathString, deviceLongAbsolutePathUnderPathMax)
        #endif
    }

    func testMixedSeperators() {
        #if os(Windows)
        XCTAssertEqual(AbsolutePath(#"C:\foo/bar"#).pathString, #"C:\foo\bar"#)
        XCTAssertEqual(AbsolutePath(#"C:\foo/bar"#).pathString, #"C:\foo\bar"#)
        XCTAssertEqual(AbsolutePath(#"\\?\C:\foo/bar"#).pathString, #"C:\foo\bar"#)
        XCTAssertEqual(AbsolutePath(#"\\.\C:\foo/bar"#).pathString, #"\\.\C:\foo\bar"#)
        #endif
    }

    func testStringInitialization() throws {
        #if !os(Windows)
        let abs1 = AbsolutePath("/")
        let abs2 = AbsolutePath(abs1, ".")
        XCTAssertEqual(abs1, abs2)
        let rel3 = "."
        let abs3 = try AbsolutePath(abs2, validating: rel3)
        XCTAssertEqual(abs2, abs3)
        let base = AbsolutePath("/base/path")
        let abs4 = AbsolutePath("/a/b/c", relativeTo: base)
        XCTAssertEqual(abs4, AbsolutePath("/a/b/c"))
        let abs5 = AbsolutePath("./a/b/c", relativeTo: base)
        XCTAssertEqual(abs5, AbsolutePath("/base/path/a/b/c"))
        let abs6 = AbsolutePath("~/bla", relativeTo: base) // `~` isn't special
        XCTAssertEqual(abs6, AbsolutePath("/base/path/~/bla"))
        #else
        let abs1 = AbsolutePath(#"C:\"#)
        let abs2 = AbsolutePath(abs1, ".")
        XCTAssertEqual(abs1, abs2)
        let rel3 = "."
        let abs3 = try AbsolutePath(abs2, validating: rel3)
        XCTAssertEqual(abs2, abs3)
        let base = AbsolutePath(#"C:\base\path"#)
        let abs4 = AbsolutePath(#"\a\b\c"#, relativeTo: base)
        XCTAssertEqual(abs4, AbsolutePath(#"C:\a\b\c"#))
        let abs5 = AbsolutePath(#".\a\b\c"#, relativeTo: base)
        XCTAssertEqual(abs5, AbsolutePath(#"C:\base\path\a\b\c"#))
        #endif
    }

    func testStringLiteralInitialization() {
        #if !os(Windows)
        let abs = AbsolutePath("/")
        XCTAssertEqual(abs.pathString, "/")
        let rel1 = RelativePath(".")
        XCTAssertEqual(rel1.pathString, ".")
        let rel2 = RelativePath("~")
        XCTAssertEqual(rel2.pathString, "~") // `~` is not special
        #else
        let abs = AbsolutePath(#"C:\"#)
        XCTAssertEqual(abs.pathString, #"C:\"#)
        let rel1 = RelativePath(".")
        XCTAssertEqual(rel1.pathString, ".")
        #endif
    }

    func testRepeatedPathSeparators() {
        #if !os(Windows)
        XCTAssertEqual(AbsolutePath("/ab//cd//ef").pathString, "/ab/cd/ef")
        XCTAssertEqual(AbsolutePath("/ab///cd//ef").pathString, "/ab/cd/ef")
        XCTAssertEqual(RelativePath("ab//cd//ef").pathString, "ab/cd/ef")
        XCTAssertEqual(RelativePath("ab//cd///ef").pathString, "ab/cd/ef")
        #else
        XCTAssertEqual(AbsolutePath(#"C:\ab\\cd\\ef"#).pathString, #"C:\ab\cd\ef"#)
        XCTAssertEqual(AbsolutePath(#"C:\ab\\cd\\ef"#).pathString, #"C:\ab\cd\ef"#)
        XCTAssertEqual(AbsolutePath(#"\\?\C:\ab\\cd\\ef"#).pathString, #"C:\ab\cd\ef"#)
        XCTAssertEqual(AbsolutePath(#"\\.\C:\ab\\cd\\ef"#).pathString, #"\\.\C:\ab\cd\ef"#)
        XCTAssertEqual(RelativePath(#"ab\\cd\\ef"#).pathString, #"ab\\cd\\ef"#)
        XCTAssertEqual(RelativePath(#"ab\\cd\\\ef"#).pathString, #"ab\\cd\\\ef"#)

        // Duplicate backslashes will be squashed, so needs to be more that PATH_MAX
        let longAbsolutePathOverPathMax = generatePath(2 * 260, duplicateSeparators: true)
        XCTAssertEqual(AbsolutePath(longAbsolutePathOverPathMax).pathString,
                       #"\\?\"# + longAbsolutePathOverPathMax.replacingOccurrences(of: #"\\"#, with: #"\"#))

        // Note: .replacingOccurrences() will squash the leading double backslash, add one extra to the start of comparision string for the \\? or \\.
        let unParsedLongAbsolutePathOverPathMax = generatePath(2 * 260, duplicateSeparators: true, useUnparsedPrefix: true)
        XCTAssertEqual(AbsolutePath(unParsedLongAbsolutePathOverPathMax).pathString,
                       #"\"# + unParsedLongAbsolutePathOverPathMax.replacingOccurrences(of: #"\\"#, with: #"\"#))
        let deviceLongAbsolutePathOverPathMax = generatePath(2 * 260, duplicateSeparators: true, useDevicePrefix: true)
        XCTAssertEqual(AbsolutePath(deviceLongAbsolutePathOverPathMax).pathString,
                       #"\"# + deviceLongAbsolutePathOverPathMax.replacingOccurrences(of: #"\\"#, with: #"\"#))


        #endif
    }

    func testTrailingPathSeparators() {
        #if !os(Windows)
        XCTAssertEqual(AbsolutePath("/ab/cd/ef/").pathString, "/ab/cd/ef")
        XCTAssertEqual(AbsolutePath("/ab/cd/ef//").pathString, "/ab/cd/ef")
        XCTAssertEqual(RelativePath("ab/cd/ef/").pathString, "ab/cd/ef")
        XCTAssertEqual(RelativePath("ab/cd/ef//").pathString, "ab/cd/ef")
        #else
        XCTAssertEqual(AbsolutePath(#"C:\"#).pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\ab\cd\ef\"#).pathString, #"C:\ab\cd\ef"#)
        XCTAssertEqual(AbsolutePath(#"C:\ab\cd\ef\\"#).pathString, #"C:\ab\cd\ef"#)
        XCTAssertEqual(AbsolutePath(#"\\?\C:\"#).pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"\\?\C:\ab\cd\ef\"#).pathString, #"C:\ab\cd\ef"#)
        XCTAssertEqual(AbsolutePath(#"\\?\C:\ab\cd\ef\\"#).pathString, #"C:\ab\cd\ef"#)
        XCTAssertEqual(AbsolutePath(#"\\.\C:\"#).pathString, #"\\.\C:"#)
        XCTAssertEqual(AbsolutePath(#"\\.\C:\ab\cd\ef\"#).pathString, #"\\.\C:\ab\cd\ef"#)
        XCTAssertEqual(AbsolutePath(#"\\.\C:\ab\cd\ef\\"#).pathString, #"\\.\C:\ab\cd\ef"#)

        XCTAssertEqual(RelativePath(#"ab\cd\ef\"#).pathString, #"ab\cd\ef\"#)
        XCTAssertEqual(RelativePath(#"ab\cd\ef\\"#).pathString, #"ab\cd\ef\\"#)

        let longAbsolutePathOverPathMax = generatePath(280)
        XCTAssertEqual(AbsolutePath(longAbsolutePathOverPathMax + #"\"#).pathString, #"\\?\"# + longAbsolutePathOverPathMax)

        let unParsedLongAbsolutePathOverPathMax = generatePath(265, useUnparsedPrefix: true)
        XCTAssertEqual(AbsolutePath(unParsedLongAbsolutePathOverPathMax + #"\"# ).pathString,
                       unParsedLongAbsolutePathOverPathMax)
        let deviceLongAbsolutePathOverPathMax = generatePath(265, useDevicePrefix: true)
        XCTAssertEqual(AbsolutePath(deviceLongAbsolutePathOverPathMax + #"\"#).pathString,
                       deviceLongAbsolutePathOverPathMax)
        #endif
    }

    func testDotPathComponents() {
        #if !os(Windows)
        XCTAssertEqual(AbsolutePath("/ab/././cd//ef").pathString, "/ab/cd/ef")
        XCTAssertEqual(AbsolutePath("/ab/./cd//ef/.").pathString, "/ab/cd/ef")
        XCTAssertEqual(RelativePath("ab/./cd/././ef").pathString, "ab/cd/ef")
        XCTAssertEqual(RelativePath("ab/./cd/ef/.").pathString, "ab/cd/ef")
        #else
        XCTAssertEqual(AbsolutePath(#"C:\ab\.\.\cd\\ef"#).pathString, #"C:\ab\cd\ef"#)
        XCTAssertEqual(AbsolutePath(#"C:\ab\.\cd\\ef\."#).pathString, #"C:\ab\cd\ef"#)
        XCTAssertEqual(AbsolutePath(#"\\?\C:\ab\.\.\cd\\ef"#).pathString, #"C:\ab\cd\ef"#)
        XCTAssertEqual(AbsolutePath(#"\\.\C:\ab\.\cd\\ef\."#).pathString, #"\\.\C:\ab\cd\ef"#)
        XCTAssertEqual(RelativePath(#"ab\.\cd\.\.\ef"#).pathString, #"ab\.\cd\.\.\ef"#)
        XCTAssertEqual(RelativePath(#"ab\.\cd\ef\."#).pathString, #"ab\.\cd\ef\."#)

        let longAbsolutePathOverPathMax = generatePath(260)
        let longAbsolutePathOverPathMaxWithDotComponents = longAbsolutePathOverPathMax + #"\.\foo\.\bar\"#
        XCTAssertEqual(AbsolutePath(longAbsolutePathOverPathMaxWithDotComponents).pathString,
                       #"\\?\"# + longAbsolutePathOverPathMax + #"\foo\bar"#)

        let unParsedLongAbsolutePathOverPathMax = generatePath(265, useUnparsedPrefix: true)
        let unParsedLongAbsolutePathOverPathMaxWithDotComponents = unParsedLongAbsolutePathOverPathMax + #"\.\foo\.\bar\"#
        XCTAssertEqual(AbsolutePath(unParsedLongAbsolutePathOverPathMaxWithDotComponents).pathString,
                       unParsedLongAbsolutePathOverPathMax + #"\foo\bar"#)

        let deviceLongAbsolutePathOverPathMax = generatePath(265, useDevicePrefix: true)
        let deviceLongAbsolutePathOverPathMaxWithDotComponents =  deviceLongAbsolutePathOverPathMax + #"\.\foo\.\bar\"#
        XCTAssertEqual(AbsolutePath(deviceLongAbsolutePathOverPathMaxWithDotComponents).pathString,
                       deviceLongAbsolutePathOverPathMax + #"\foo\bar"#)
        #endif
    }

    func testDotDotPathComponents() {
        #if !os(Windows)
        XCTAssertEqual(AbsolutePath("/..").pathString, "/")
        XCTAssertEqual(AbsolutePath("/../../../../..").pathString, "/")
        XCTAssertEqual(AbsolutePath("/abc/..").pathString, "/")
        XCTAssertEqual(AbsolutePath("/abc/../..").pathString, "/")
        XCTAssertEqual(AbsolutePath("/../abc").pathString, "/abc")
        XCTAssertEqual(AbsolutePath("/../abc/..").pathString, "/")
        XCTAssertEqual(AbsolutePath("/../abc/../def").pathString, "/def")
        XCTAssertEqual(RelativePath("..").pathString, "..")
        XCTAssertEqual(RelativePath("../..").pathString, "../..")
        XCTAssertEqual(RelativePath(".././..").pathString, "../..")
        XCTAssertEqual(RelativePath("../abc/..").pathString, "..")
        XCTAssertEqual(RelativePath("../abc/.././").pathString, "..")
        XCTAssertEqual(RelativePath("abc/..").pathString, ".")
        #else
        XCTAssertEqual(AbsolutePath(#"C:\.."#).pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\..\..\..\..\.."#).pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\abc\.."#).pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\abc\..\.."#).pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\..\abc"#).pathString, #"C:\abc"#)
        XCTAssertEqual(AbsolutePath(#"C:\..\abc\.."#).pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\..\abc\..\def"#).pathString, #"C:\def"#)

        XCTAssertEqual(RelativePath(#".."#).pathString, #".."#)
        XCTAssertEqual(RelativePath(#"..\.."#).pathString, #"..\.."#)
        XCTAssertEqual(RelativePath(#"..\.\.."#).pathString, #"..\.\.."#)
        XCTAssertEqual(RelativePath(#"..\abc\.."#).pathString, #"..\abc\.."#)
        XCTAssertEqual(RelativePath(#"..\abc\..\.\"#).pathString, #"..\abc\..\.\"#)
        XCTAssertEqual(RelativePath(#"abc\.."#).pathString, #"abc\.."#)
        let longAbsolutePathOverPathMax = generatePath(280)
        XCTAssertEqual(AbsolutePath(longAbsolutePathOverPathMax + #"\abc\..\"#).pathString, #"\\?\"# + longAbsolutePathOverPathMax)
        let unParsedLongAbsolutePathOverPathMax = generatePath(280, useUnparsedPrefix: true)
        XCTAssertEqual(AbsolutePath(unParsedLongAbsolutePathOverPathMax + #"\abc\..\"#).pathString, unParsedLongAbsolutePathOverPathMax)
        let deviceLongAbsolutePathOverPathMax = generatePath(280, useDevicePrefix: true)
        XCTAssertEqual(AbsolutePath(deviceLongAbsolutePathOverPathMax + #"\abc\..\"#).pathString, deviceLongAbsolutePathOverPathMax)

        #endif
    }

    func testCombinationsAndEdgeCases() {
        #if !os(Windows)
        XCTAssertEqual(AbsolutePath("///").pathString, "/")
        XCTAssertEqual(AbsolutePath("/./").pathString, "/")
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
        #else
        XCTAssertEqual(AbsolutePath(#"C:\\\"#).pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\.\"#).pathString, #"C:\"#)
        XCTAssertEqual(RelativePath("").pathString, ".")
        XCTAssertEqual(RelativePath(".").pathString, ".")
        XCTAssertEqual(RelativePath(#".\abc"#).pathString, #".\abc"#)
        XCTAssertEqual(RelativePath(#".\abc\"#).pathString, #".\abc\"#)
        XCTAssertEqual(RelativePath(#".\abc\..\bar"#).pathString, #".\abc\..\bar"#)
        XCTAssertEqual(RelativePath(#"foo\..\bar"#).pathString, #"foo\..\bar"#)
        XCTAssertEqual(RelativePath(#"foo\\\..\\\bar\\\baz"#).pathString, #"foo\\\..\\\bar\\\baz"#)
        XCTAssertEqual(RelativePath(#"foo\..\bar\.\"#).pathString, #"foo\..\bar\.\"#)
        XCTAssertEqual(RelativePath(#"..\abc\def\"#).pathString, #"..\abc\def\"#)
        XCTAssertEqual(RelativePath(#".\.\.\.\."#).pathString, #".\.\.\.\."#)
        XCTAssertEqual(RelativePath(#".\.\.\..\."#).pathString, #".\.\.\..\."#)
        XCTAssertEqual(RelativePath(#".\"#).pathString, #".\"#)
        XCTAssertEqual(RelativePath(#".\\"#).pathString, #".\\"#)
        XCTAssertEqual(RelativePath(#".\."#).pathString, #".\."#)
        XCTAssertEqual(RelativePath(#".\.\"#).pathString, #".\.\"#)
        XCTAssertEqual(RelativePath(#"..\"#).pathString, #"..\"#)
        XCTAssertEqual(RelativePath(#"..\."#).pathString, #"..\."#)
        XCTAssertEqual(RelativePath(#".\.."#).pathString, #".\.."#)
        XCTAssertEqual(RelativePath(#".\..\."#).pathString, #".\..\."#)
        XCTAssertEqual(RelativePath(#".\\\\\..\\\\\.\\\\\"#).pathString, #".\\\\\..\\\\\.\\\\\"#)
        XCTAssertEqual(RelativePath(#"..\a"#).pathString, #"..\a"#)
        XCTAssertEqual(RelativePath(#"..\a\.."#).pathString, #"..\a\.."#)
        XCTAssertEqual(RelativePath(#"a\.."#).pathString, #"a\.."#)
        XCTAssertEqual(RelativePath(#"a\..\\\\\..\\\\\.\\\\\"#).pathString, #"a\..\\\\\..\\\\\.\\\\\"#)
        #endif
    }

    func testDirectoryNameExtraction() {
        #if !os(Windows)
        XCTAssertEqual(AbsolutePath("/").dirname, "/")
        XCTAssertEqual(AbsolutePath("/a").dirname, "/")
        XCTAssertEqual(AbsolutePath("/./a").dirname, "/")
        XCTAssertEqual(AbsolutePath("/../..").dirname, "/")
        XCTAssertEqual(AbsolutePath("/ab/c//d/").dirname, "/ab/c")
        XCTAssertEqual(RelativePath("ab/c//d/").dirname, "ab/c")
        XCTAssertEqual(RelativePath("../a").dirname, "..")
        XCTAssertEqual(RelativePath("../a/..").dirname, ".")
        XCTAssertEqual(RelativePath("a/..").dirname, ".")
        XCTAssertEqual(RelativePath("./..").dirname, ".")
        XCTAssertEqual(RelativePath("a/../////../////./////").dirname, ".")
        XCTAssertEqual(RelativePath("abc").dirname, ".")
        XCTAssertEqual(RelativePath("").dirname, ".")
        XCTAssertEqual(RelativePath(".").dirname, ".")
        #else
        XCTAssertEqual(AbsolutePath(#"C:\a\b"#).dirname, #"C:\a"#)
        XCTAssertEqual(AbsolutePath(#"C:\"#).dirname, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\\"#).dirname, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\\\"#).dirname, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\a\b\"#).dirname, #"C:\a"#)
        XCTAssertEqual(AbsolutePath(#"C:\a\b\\"#).dirname, #"C:\a"#)
        XCTAssertEqual(AbsolutePath(#"C:\a\"#).dirname, #"C:\"#)

        XCTAssertEqual(AbsolutePath(#"\\?\C:\a\b"#).dirname, #"C:\a"#)
        XCTAssertEqual(AbsolutePath(#"\\?\C:\"#).dirname, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"\\?\C:\\"#).dirname, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"\\?\C:\\\"#).dirname, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"\\?\C:\a\b\"#).dirname, #"C:\a"#)
        XCTAssertEqual(AbsolutePath(#"\\?\C:\a\b\\"#).dirname, #"C:\a"#)
        XCTAssertEqual(AbsolutePath(#"\\?\C:\a\"#).dirname, #"C:\"#)

        XCTAssertEqual(AbsolutePath(#"\\.\C:\a\b"#).dirname, #"\\.\C:\a"#)
        XCTAssertEqual(AbsolutePath(#"\\.\C:\"#).dirname, #"\\.\C:"#)
        XCTAssertEqual(AbsolutePath(#"\\.\C:\\"#).dirname, #"\\.\C:"#)
        XCTAssertEqual(AbsolutePath(#"\\.\C:\\\"#).dirname, #"\\.\C:"#)
        XCTAssertEqual(AbsolutePath(#"\\.\C:\a\b\"#).dirname, #"\\.\C:\a"#)
        XCTAssertEqual(AbsolutePath(#"\\.\C:\a\b\\"#).dirname, #"\\.\C:\a"#)
        XCTAssertEqual(AbsolutePath(#"\\.\C:\a\"#).dirname, #"\\.\C:"#)

        let longAbsolutePathOverPathMax = generatePath(280)
        XCTAssertEqual(AbsolutePath(longAbsolutePathOverPathMax + #"\a.txt"#).dirname, #"\\?\"# + longAbsolutePathOverPathMax)
        let unParsedLongAbsolutePathOverPathMax = generatePath(280, useUnparsedPrefix: true)
        XCTAssertEqual(AbsolutePath(unParsedLongAbsolutePathOverPathMax + #"\a.txt"#).dirname, unParsedLongAbsolutePathOverPathMax)
        let deviceLongAbsolutePathOverPathMax = generatePath(280, useDevicePrefix: true)
        XCTAssertEqual(AbsolutePath(deviceLongAbsolutePathOverPathMax + #"\a.txt"#).dirname, deviceLongAbsolutePathOverPathMax)
        #endif
    }

    func testBaseNameExtraction() {
        #if !os(Windows)
        XCTAssertEqual(AbsolutePath("/").basename, "/")
        XCTAssertEqual(AbsolutePath("/a").basename, "a")
        XCTAssertEqual(AbsolutePath("/./a").basename, "a")
        XCTAssertEqual(AbsolutePath("/../..").basename, "/")
        XCTAssertEqual(RelativePath("../..").basename, "..")
        XCTAssertEqual(RelativePath("../a").basename, "a")
        XCTAssertEqual(RelativePath("../a/..").basename, "..")
        XCTAssertEqual(RelativePath("a/..").basename, ".")
        XCTAssertEqual(RelativePath("./..").basename, "..")
        XCTAssertEqual(RelativePath("a/../////../////./////").basename, "..")
        XCTAssertEqual(RelativePath("abc").basename, "abc")
        XCTAssertEqual(RelativePath("").basename, ".")
        XCTAssertEqual(RelativePath(".").basename, ".")
        #else
        XCTAssertEqual(AbsolutePath(#"C:\"#).basename, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\a"#).basename, #"a"#)
        XCTAssertEqual(AbsolutePath(#"C:\.\a"#).basename, #"a"#)
        XCTAssertEqual(AbsolutePath(#"C:\..\.."#).basename, #"C:\"#)
        XCTAssertEqual(RelativePath(#"..\.."#).basename, #".."#)
        XCTAssertEqual(RelativePath(#"..\a"#).basename, #"a"#)
        XCTAssertEqual(RelativePath(#"..\a\.."#).basename, #".."#)
        XCTAssertEqual(RelativePath(#"a\.."#).basename, #".."#)
        XCTAssertEqual(RelativePath(#".\.."#).basename, #".."#)
        XCTAssertEqual(RelativePath(#"a\..\\\\..\\\\.\\\\"#).basename, #".\\\\"#)
        XCTAssertEqual(RelativePath(#"abc"#).basename, #"abc"#)
        XCTAssertEqual(RelativePath(#""#).basename, #"."#)
        XCTAssertEqual(RelativePath(#"."#).basename, #"."#)
        let longAbsolutePathOverPathMax = generatePath(280)
        XCTAssertEqual(AbsolutePath(longAbsolutePathOverPathMax + #"\a.txt"#).basename, #"a.txt"#)
        let unParsedLongAbsolutePathOverPathMax = generatePath(280, useUnparsedPrefix: true)
        XCTAssertEqual(AbsolutePath(unParsedLongAbsolutePathOverPathMax + #"\a.txt"#).basename, #"a.txt"#)
        let deviceLongAbsolutePathOverPathMax = generatePath(280, useDevicePrefix: true)
        XCTAssertEqual(AbsolutePath(deviceLongAbsolutePathOverPathMax + #"\a.txt"#).basename, #"a.txt"#)
        #endif
    }

    func testBaseNameWithoutExt() {
        #if !os(Windows)
        XCTAssertEqual(AbsolutePath("/").basenameWithoutExt, "/")
        XCTAssertEqual(AbsolutePath("/a").basenameWithoutExt, "a")
        XCTAssertEqual(AbsolutePath("/./a").basenameWithoutExt, "a")
        XCTAssertEqual(AbsolutePath("/../..").basenameWithoutExt, "/")
        XCTAssertEqual(RelativePath("../..").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath("../a").basenameWithoutExt, "a")
        XCTAssertEqual(RelativePath("../a/..").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath("a/..").basenameWithoutExt, ".")
        XCTAssertEqual(RelativePath("./..").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath("a/../////../////./////").basenameWithoutExt, "..")
        XCTAssertEqual(RelativePath("abc").basenameWithoutExt, "abc")
        XCTAssertEqual(RelativePath("").basenameWithoutExt, ".")
        XCTAssertEqual(RelativePath(".").basenameWithoutExt, ".")

        XCTAssertEqual(AbsolutePath("/a.txt").basenameWithoutExt, "a")
        XCTAssertEqual(AbsolutePath("/./a.txt").basenameWithoutExt, "a")
        XCTAssertEqual(RelativePath("../a.bc").basenameWithoutExt, "a")
        XCTAssertEqual(RelativePath("abc.swift").basenameWithoutExt, "abc")
        XCTAssertEqual(RelativePath("../a.b.c").basenameWithoutExt, "a.b")
        XCTAssertEqual(RelativePath("abc.xyz.123").basenameWithoutExt, "abc.xyz")
        #else
        XCTAssertEqual(AbsolutePath(#"C:\"#).basenameWithoutExt, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\a"#).basenameWithoutExt, #"a"#)
        XCTAssertEqual(AbsolutePath(#"C:\.\a"#).basenameWithoutExt, #"a"#)
        XCTAssertEqual(AbsolutePath(#"C:\..\.."#).basenameWithoutExt, #"C:\"#)
        XCTAssertEqual(RelativePath(#"..\.."#).basenameWithoutExt, #".."#)
        XCTAssertEqual(RelativePath(#"..\a"#).basenameWithoutExt, #"a"#)
        XCTAssertEqual(RelativePath(#"..\a\.."#).basenameWithoutExt, #".."#)
        XCTAssertEqual(RelativePath(#"a\.."#).basenameWithoutExt, #".."#)
        XCTAssertEqual(RelativePath(#".\.."#).basenameWithoutExt, #".."#)
        XCTAssertEqual(RelativePath(#"a\..\\\\..\\\\.\\\\"#).basenameWithoutExt, #".\\\\"#)
        XCTAssertEqual(RelativePath(#"abc"#).basenameWithoutExt, #"abc"#)
        XCTAssertEqual(RelativePath(#""#).basenameWithoutExt, #"."#)
        XCTAssertEqual(RelativePath(#"."#).basenameWithoutExt, #"."#)

        XCTAssertEqual(AbsolutePath(#"C:\a.txt"#).basenameWithoutExt, #"a"#)
        XCTAssertEqual(AbsolutePath(#"C:\.\a.txt"#).basenameWithoutExt, #"a"#)
        XCTAssertEqual(RelativePath(#"..\a.bc"#).basenameWithoutExt, #"a"#)
        XCTAssertEqual(RelativePath(#"abc.swift"#).basenameWithoutExt, #"abc"#)
        XCTAssertEqual(RelativePath(#"..\a.b.c"#).basenameWithoutExt, #"a.b"#)
        XCTAssertEqual(RelativePath(#"abc.xyz.123"#).basenameWithoutExt, #"abc.xyz"#)

        let longAbsolutePathOverPathMax = generatePath(280)
        XCTAssertEqual(AbsolutePath(longAbsolutePathOverPathMax + #"\a.txt"#).basenameWithoutExt, #"a"#)
        let unParsedLongAbsolutePathOverPathMax = generatePath(280, useUnparsedPrefix: true)
        XCTAssertEqual(AbsolutePath(unParsedLongAbsolutePathOverPathMax + #"\a.txt"#).basenameWithoutExt, #"a"#)
        let deviceLongAbsolutePathOverPathMax = generatePath(280, useDevicePrefix: true)
        XCTAssertEqual(AbsolutePath(deviceLongAbsolutePathOverPathMax + #"\a.txt"#).basenameWithoutExt, #"a"#)
        #endif
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
        #if !os(Windows)
        XCTAssertEqual(AbsolutePath("/").parentDirectory, AbsolutePath("/"))
        XCTAssertEqual(AbsolutePath("/").parentDirectory.parentDirectory, AbsolutePath("/"))
        XCTAssertEqual(AbsolutePath("/bar").parentDirectory, AbsolutePath("/"))
        XCTAssertEqual(AbsolutePath("/bar/../foo/..//").parentDirectory.parentDirectory, AbsolutePath("/"))
        XCTAssertEqual(AbsolutePath("/bar/../foo/..//yabba/a/b").parentDirectory.parentDirectory, AbsolutePath("/yabba"))
        #else
        XCTAssertEqual(AbsolutePath(#"C:\"#).parentDirectory, AbsolutePath(#"C:\"#))
        XCTAssertEqual(AbsolutePath(#"C:\"#).parentDirectory.parentDirectory, AbsolutePath(#"C:\"#))
        XCTAssertEqual(AbsolutePath(#"C:\bar"#).parentDirectory, AbsolutePath(#"C:\"#))
        XCTAssertEqual(AbsolutePath(#"C:\bar\..\foo\..\\"#).parentDirectory.parentDirectory, AbsolutePath(#"C:\"#))
        XCTAssertEqual(AbsolutePath(#"C:\bar\..\foo\..\\yabba\a\b"#).parentDirectory.parentDirectory, AbsolutePath(#"C:\yabba"#))
        let longAbsolutePathOverPathMax = generatePath(280)
        XCTAssertEqual(AbsolutePath(longAbsolutePathOverPathMax).parentDirectory, AbsolutePath(longAbsolutePathOverPathMax.replacingOccurrences(of: #"\95"#, with: "")))
        let unParsedLongAbsolutePathOverPathMax = generatePath(280, useUnparsedPrefix: true)
        XCTAssertEqual(AbsolutePath(unParsedLongAbsolutePathOverPathMax).parentDirectory, AbsolutePath(unParsedLongAbsolutePathOverPathMax.replacingOccurrences(of: #"\94"#, with: "")))
        let deviceLongAbsolutePathOverPathMax = generatePath(280, useDevicePrefix: true)
        XCTAssertEqual(AbsolutePath(deviceLongAbsolutePathOverPathMax).parentDirectory, AbsolutePath(deviceLongAbsolutePathOverPathMax.replacingOccurrences(of: #"\94"#, with: "")))
        #endif
    }

    @available(*, deprecated)
    func testConcatenation() {
        #if !os(Windows)
        XCTAssertEqual(AbsolutePath(AbsolutePath("/"), RelativePath("")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath("/"), RelativePath(".")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath("/"), RelativePath("..")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath("/"), RelativePath("bar")).pathString, "/bar")
        XCTAssertEqual(AbsolutePath(AbsolutePath("/foo/bar"), RelativePath("..")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath(AbsolutePath("/bar"), RelativePath("../foo")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath(AbsolutePath("/bar"), RelativePath("../foo/..//")).pathString, "/")
        XCTAssertEqual(AbsolutePath(AbsolutePath("/bar/../foo/..//yabba/"), RelativePath("a/b")).pathString, "/yabba/a/b")

        XCTAssertEqual(AbsolutePath("/").appending(RelativePath("")).pathString, "/")
        XCTAssertEqual(AbsolutePath("/").appending(RelativePath(".")).pathString, "/")
        XCTAssertEqual(AbsolutePath("/").appending(RelativePath("..")).pathString, "/")
        XCTAssertEqual(AbsolutePath("/").appending(RelativePath("bar")).pathString, "/bar")
        XCTAssertEqual(AbsolutePath("/foo/bar").appending(RelativePath("..")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath("/bar").appending(RelativePath("../foo")).pathString, "/foo")
        XCTAssertEqual(AbsolutePath("/bar").appending(RelativePath("../foo/..//")).pathString, "/")
        XCTAssertEqual(AbsolutePath("/bar/../foo/..//yabba/").appending(RelativePath("a/b")).pathString, "/yabba/a/b")

        XCTAssertEqual(AbsolutePath("/").appending(component: "a").pathString, "/a")
        XCTAssertEqual(AbsolutePath("/a").appending(component: "b").pathString, "/a/b")
        XCTAssertEqual(AbsolutePath("/").appending(components: "a", "b").pathString, "/a/b")
        XCTAssertEqual(AbsolutePath("/a").appending(components: "b", "c").pathString, "/a/b/c")

        XCTAssertEqual(AbsolutePath("/a/b/c").appending(components: "", "c").pathString, "/a/b/c/c")
        XCTAssertEqual(AbsolutePath("/a/b/c").appending(components: "").pathString, "/a/b/c")
        XCTAssertEqual(AbsolutePath("/a/b/c").appending(components: ".").pathString, "/a/b/c")
        XCTAssertEqual(AbsolutePath("/a/b/c").appending(components: "..").pathString, "/a/b")
        XCTAssertEqual(AbsolutePath("/a/b/c").appending(components: "..", "d").pathString, "/a/b/d")
        XCTAssertEqual(AbsolutePath("/").appending(components: "..").pathString, "/")
        XCTAssertEqual(AbsolutePath("/").appending(components: ".").pathString, "/")
        XCTAssertEqual(AbsolutePath("/").appending(components: "..", "a").pathString, "/a")

        XCTAssertEqual(RelativePath("hello").appending(components: "a", "b", "c", "..").pathString, "hello/a/b")
        XCTAssertEqual(RelativePath("hello").appending(RelativePath("a/b/../c/d")).pathString, "hello/a/c/d")
        #else
        XCTAssertEqual(AbsolutePath(AbsolutePath(#"C:\"#), RelativePath("")).pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(AbsolutePath(#"C:\"#), RelativePath(".")).pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(AbsolutePath(#"C:\"#), RelativePath("..")).pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(AbsolutePath(#"C:\"#), RelativePath("bar")).pathString, #"C:\bar"#)
        XCTAssertEqual(AbsolutePath(AbsolutePath(#"C:\foo\bar"#), RelativePath("..")).pathString, #"C:\foo"#)
        XCTAssertEqual(AbsolutePath(AbsolutePath(#"C:\bar"#), RelativePath(#"..\foo"#)).pathString, #"C:\foo"#)
        XCTAssertEqual(AbsolutePath(AbsolutePath(#"C:\bar"#), RelativePath(#"..\foo\..\\"#)).pathString, #"C:\\"#)
        XCTAssertEqual(AbsolutePath(AbsolutePath(#"C:\bar\..\foo\..\\yabba\"#), RelativePath("a/b")).pathString, #"C:\yabba\a\b"#)

        XCTAssertEqual(AbsolutePath(#"C:\"#).appending(RelativePath("")).pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\"#).appending(RelativePath(".")).pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\"#).appending(RelativePath("..")).pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\"#).appending(RelativePath("bar")).pathString, #"C:\bar"#)
        XCTAssertEqual(AbsolutePath(#"C:\foo\bar"#).appending(RelativePath("..")).pathString, #"C:\foo"#)
        XCTAssertEqual(AbsolutePath(#"C:\bar"#).appending(RelativePath(#"..\foo"#)).pathString, #"C:\foo"#)
        XCTAssertEqual(AbsolutePath(#"C:\bar"#).appending(RelativePath(#"..\foo\..\\"#)).pathString, #"C:\\"#)
        XCTAssertEqual(AbsolutePath(#"C:\bar\..\foo\..\\yabba\"#).appending(RelativePath(#"a\b"#)).pathString, #"C:\yabba\a\b"#)

        XCTAssertEqual(AbsolutePath(#"C:\"#).appending(component: "a").pathString, #"C:\a"#)
        XCTAssertEqual(AbsolutePath(#"C:\a"#).appending(component: "b").pathString, #"C:\a\b"#)
        XCTAssertEqual(AbsolutePath(#"C:\"#).appending(components: "a", "b").pathString, #"C:\a\b"#)
        XCTAssertEqual(AbsolutePath(#"C:\a"#).appending(components: "b", "c").pathString, #"C:\a\b\c"#)

        XCTAssertEqual(AbsolutePath(#"C:\a\b\c"#).appending(components: "", "c").pathString, #"C:\a\b\c\c"#)
        XCTAssertEqual(AbsolutePath(#"C:\a\b\c"#).appending(components: "").pathString, #"C:\a\b\c"#)
        XCTAssertEqual(AbsolutePath(#"C:\a\b\c"#).appending(components: ".").pathString, #"C:\a\b\c"#)
        XCTAssertEqual(AbsolutePath(#"C:\a\b\c"#).appending(components: "..").pathString, #"C:\a\b"#)
        XCTAssertEqual(AbsolutePath(#"C:\a\b\c"#).appending(components: "..", "d").pathString, #"C:\a\b\d"#)
        XCTAssertEqual(AbsolutePath(#"C:\"#).appending(components: "..").pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\"#).appending(components: ".").pathString, #"C:\"#)
        XCTAssertEqual(AbsolutePath(#"C:\"#).appending(components: "..", "a").pathString, #"C:\a"#)

        XCTAssertEqual(RelativePath("hello").appending(components: "a", "b", "c", "..").pathString, #"hello\a\b"#)
        XCTAssertEqual(RelativePath("hello").appending(RelativePath(#"a\b\..\c\d"#)).pathString, #"hello\a\c\d"#)

        var longAbsolutePathUnderPathMax = generatePath(255)
        XCTAssertEqual(AbsolutePath(longAbsolutePathUnderPathMax).appending(components: "a", "b", "c", "d", "e").pathString,
                       #"\\?\"# + longAbsolutePathUnderPathMax + #"\a\b\c\d\e"#)
        longAbsolutePathUnderPathMax = generatePath(255)
        XCTAssertEqual(AbsolutePath(longAbsolutePathUnderPathMax).appending(RelativePath(#"a\b\..\c\d"#)).pathString,
                       #"\\?\"# + longAbsolutePathUnderPathMax + #"\a\c\d"#)
        #endif
    }

    func testPathComponents() {
        #if !os(Windows)
        XCTAssertEqual(AbsolutePath("/").components, ["/"])
        XCTAssertEqual(AbsolutePath("/.").components, ["/"])
        XCTAssertEqual(AbsolutePath("/..").components, ["/"])
        XCTAssertEqual(AbsolutePath("/bar").components, ["/", "bar"])
        XCTAssertEqual(AbsolutePath("/foo/bar/..").components, ["/", "foo"])
        XCTAssertEqual(AbsolutePath("/bar/../foo").components, ["/", "foo"])
        XCTAssertEqual(AbsolutePath("/bar/../foo/..//").components, ["/"])
        XCTAssertEqual(AbsolutePath("/bar/../foo/..//yabba/a/b/").components, ["/", "yabba", "a", "b"])

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
        #else
        XCTAssertEqual(AbsolutePath(#"C:\"#).components, ["C:"])
        XCTAssertEqual(AbsolutePath(#"C:\."#).components, ["C:"])
        XCTAssertEqual(AbsolutePath(#"C:\.."#).components, ["C:"])
        XCTAssertEqual(AbsolutePath(#"C:\bar"#).components, ["C:", "bar"])
        XCTAssertEqual(AbsolutePath(#"C:\foo/bar/.."#).components, ["C:", "foo"])
        XCTAssertEqual(AbsolutePath(#"C:\bar/../foo"#).components, ["C:", "foo"])
        XCTAssertEqual(AbsolutePath(#"C:\bar/../foo/..//"#).components, ["C:"])
        XCTAssertEqual(AbsolutePath(#"C:\bar/../foo/..//yabba/a/b/"#).components, ["C:", "yabba", "a", "b"])

        XCTAssertEqual(AbsolutePath(#"\\?\C:\"#).components, ["C:"])
        XCTAssertEqual(AbsolutePath(#"\\?\C:\."#).components, ["C:"])
        XCTAssertEqual(AbsolutePath(#"\\?\C:\bar"#).components, ["C:", "bar"])
        XCTAssertEqual(AbsolutePath(#"\\?\C:\foo/bar/.."#).components, ["C:", "foo"])
        XCTAssertEqual(AbsolutePath(#"\\?\C:\bar/../foo"#).components, ["C:", "foo"])
        XCTAssertEqual(AbsolutePath(#"\\?\C:\bar/../foo/..//"#).components, ["C:"])
        XCTAssertEqual(AbsolutePath(#"\\?\C:\bar/../foo/..//yabba/a/b/"#).components, ["C:", "yabba", "a", "b"])

        XCTAssertEqual(AbsolutePath(#"\\.\C:\"#).components, ["C:"])
        XCTAssertEqual(AbsolutePath(#"\\.\C:\."#).components, ["C:"])
        XCTAssertEqual(AbsolutePath(#"\\.\C:\bar"#).components, ["C:", "bar"])
        XCTAssertEqual(AbsolutePath(#"\\.\C:\foo/bar/.."#).components, ["C:", "foo"])
        XCTAssertEqual(AbsolutePath(#"\\.\C:\bar/../foo"#).components, ["C:", "foo"])
        XCTAssertEqual(AbsolutePath(#"\\.\C:\bar/../foo/..//"#).components, ["C:"])
        XCTAssertEqual(AbsolutePath(#"\\.\C:\bar/../foo/..//yabba/a/b/"#).components, ["C:", "yabba", "a", "b"])

        XCTAssertEqual(RelativePath(#""#).components, ["."])
        XCTAssertEqual(RelativePath(#"."#).components, ["."])
        XCTAssertEqual(RelativePath(#".."#).components, [".."])
        XCTAssertEqual(RelativePath(#"bar"#).components, ["bar"])
        XCTAssertEqual(RelativePath(#"foo/bar/.."#).components, ["foo", "bar", ".."])
        XCTAssertEqual(RelativePath(#"bar/../foo"#).components, ["bar", "..", "foo"])
        XCTAssertEqual(RelativePath(#"bar/../foo/..//"#).components, ["bar", "..", "foo", ".."])
        XCTAssertEqual(RelativePath(#"bar/../foo/..//yabba/a/b/"#).components, ["bar", "..", "foo", "..", "yabba", "a", "b"])
        XCTAssertEqual(RelativePath(#"../.."#).components, ["..", ".."])
        XCTAssertEqual(RelativePath(#".././/.."#).components, ["..", ".", ".."])
        XCTAssertEqual(RelativePath(#"../a"#).components, ["..", "a"])
        XCTAssertEqual(RelativePath(#"../a/.."#).components, ["..", "a", ".."])
        XCTAssertEqual(RelativePath(#"a/.."#).components, ["a", ".."])
        XCTAssertEqual(RelativePath(#"./.."#).components, [".", ".."])
        XCTAssertEqual(RelativePath(#"a/../////../////./////"#).components, ["a", "..", "..", "."])
        XCTAssertEqual(RelativePath(#"abc"#).components, ["abc"])
        #endif
    }

    func testRelativePathFromAbsolutePaths() {
        #if !os(Windows)
        XCTAssertEqual(AbsolutePath("/").relative(to: AbsolutePath("/")), RelativePath("."))
        XCTAssertEqual(AbsolutePath("/a/b/c/d").relative(to: AbsolutePath("/")), RelativePath("a/b/c/d"))
        XCTAssertEqual(AbsolutePath("/").relative(to: AbsolutePath("/a/b/c")), RelativePath("../../.."))
        XCTAssertEqual(AbsolutePath("/a/b/c/d").relative(to: AbsolutePath("/a/b")), RelativePath("c/d"))
        XCTAssertEqual(AbsolutePath("/a/b/c/d").relative(to: AbsolutePath("/a/b/c")), RelativePath("d"))
        XCTAssertEqual(AbsolutePath("/a/b/c/d").relative(to: AbsolutePath("/a/c/d")), RelativePath("../../b/c/d"))
        XCTAssertEqual(AbsolutePath("/a/b/c/d").relative(to: AbsolutePath("/b/c/d")), RelativePath("../../../a/b/c/d"))
        #else
        XCTAssertEqual(AbsolutePath(#"C:\"#).relative(to: AbsolutePath(#"C:\"#)), RelativePath("."))
        XCTAssertEqual(AbsolutePath(#"C:\a/b/c/d"#).relative(to: AbsolutePath(#"C:\"#)), RelativePath(#"a\b\c\d"#))
        XCTAssertEqual(AbsolutePath(#"C:\"#).relative(to: AbsolutePath(#"C:\a\b\c"#)), RelativePath(#"..\..\.."#))
        XCTAssertEqual(AbsolutePath(#"C:\a\b\c\d"#).relative(to: AbsolutePath(#"C:\a\b"#)), RelativePath(#"c\d"#))
        XCTAssertEqual(AbsolutePath(#"C:\a\b\c\d"#).relative(to: AbsolutePath(#"C:\a\b\c"#)), RelativePath(#"d"#))
        XCTAssertEqual(AbsolutePath(#"C:\a\b\c\d"#).relative(to: AbsolutePath(#"C:\a\c\d"#)), RelativePath(#"..\..\b\c\d"#))
        XCTAssertEqual(AbsolutePath(#"C:\a\b\c\d"#).relative(to: AbsolutePath(#"C:\b\c\d"#)), RelativePath(#"..\..\..\a\b\c\d"#))

        XCTAssertEqual(AbsolutePath(#"\\?\C:\"#).relative(to: AbsolutePath(#"C:\"#)), RelativePath("."))
        XCTAssertEqual(AbsolutePath(#"\\?\C:\a/b/c/d"#).relative(to: AbsolutePath(#"C:\"#)), RelativePath(#"a\b\c\d"#))
        XCTAssertEqual(AbsolutePath(#"\\?\C:\"#).relative(to: AbsolutePath(#"C:\a\b\c"#)), RelativePath(#"..\..\.."#))
        XCTAssertEqual(AbsolutePath(#"\\?\C:\a\b\c\d"#).relative(to: AbsolutePath(#"C:\a\b"#)), RelativePath(#"c\d"#))
        XCTAssertEqual(AbsolutePath(#"\\?\C:\a\b\c\d"#).relative(to: AbsolutePath(#"C:\a\b\c"#)), RelativePath(#"d"#))
        XCTAssertEqual(AbsolutePath(#"\\?\C:\a\b\c\d"#).relative(to: AbsolutePath(#"C:\a\c\d"#)), RelativePath(#"..\..\b\c\d"#))
        XCTAssertEqual(AbsolutePath(#"\\?\C:\a\b\c\d"#).relative(to: AbsolutePath(#"C:\b\c\d"#)), RelativePath(#"..\..\..\a\b\c\d"#))

        var longAbsolutePathOverPathMax = generatePath(264)
        XCTAssertEqual(
            AbsolutePath(longAbsolutePathOverPathMax).relative(to: AbsolutePath(longAbsolutePathOverPathMax.replacingOccurrences(of: #"\85\86\87\88\89\90"#, with: ""))),
            RelativePath(#"85\86\87\88\89\90"#)
        )
        var unParsedLongAbsolutePathOverPathMax = generatePath(264, useUnparsedPrefix: true)
        XCTAssertEqual(
            AbsolutePath(unParsedLongAbsolutePathOverPathMax).relative(to: AbsolutePath(unParsedLongAbsolutePathOverPathMax.replacingOccurrences(of: #"\85\86\87\88\89"#, with: ""))),
            RelativePath(#"85\86\87\88\89"#)
        )
        var deviceLongAbsolutePathOverPathMax = generatePath(264, useDevicePrefix: true)
        XCTAssertEqual(
            AbsolutePath(unParsedLongAbsolutePathOverPathMax).relative(to: AbsolutePath(unParsedLongAbsolutePathOverPathMax.replacingOccurrences(of: #"\85\86\87\88\89"#, with: ""))),
            RelativePath(#"85\86\87\88\89"#)
        )

        #endif
    }

    func testComparison() {
        #if !os(Windows)
        XCTAssertTrue(AbsolutePath("/") <= AbsolutePath("/"))
        XCTAssertTrue(AbsolutePath("/abc") < AbsolutePath("/def"))
        XCTAssertTrue(AbsolutePath("/2") <= AbsolutePath("/2.1"))
        XCTAssertTrue(AbsolutePath("/3.1") > AbsolutePath("/2"))
        XCTAssertTrue(AbsolutePath("/2") >= AbsolutePath("/2"))
        XCTAssertTrue(AbsolutePath("/2.1") >= AbsolutePath("/2"))
        #else
        XCTAssertTrue(AbsolutePath(#"C:\"#) <= AbsolutePath(#"C:\"#))
        XCTAssertTrue(AbsolutePath(#"C:\abc"#) < AbsolutePath(#"C:\def"#))
        XCTAssertTrue(AbsolutePath(#"C:\2"#) <= AbsolutePath(#"C:\2.1"#))
        XCTAssertTrue(AbsolutePath(#"C:\3.1"#) > AbsolutePath(#"C:\2"#))
        XCTAssertTrue(AbsolutePath(#"C:\2"#) >= AbsolutePath(#"C:\2"#))
        XCTAssertTrue(AbsolutePath(#"C:\2.1"#) >= AbsolutePath(#"C:\2"#))

        let longAbsolutePathOverPathMax = generatePath(260)
        XCTAssertTrue(AbsolutePath(longAbsolutePathOverPathMax + #"\abc"#) < AbsolutePath(longAbsolutePathOverPathMax + #"\def"#))
        XCTAssertTrue(AbsolutePath(longAbsolutePathOverPathMax + #"\2"#) <= AbsolutePath(longAbsolutePathOverPathMax + #"\2.1"#))
        XCTAssertTrue(AbsolutePath(longAbsolutePathOverPathMax + #"\3.1"#) > AbsolutePath(longAbsolutePathOverPathMax + #"\2"#))
        XCTAssertTrue(AbsolutePath(longAbsolutePathOverPathMax + #"\2"#) >= AbsolutePath(longAbsolutePathOverPathMax + #"\2"#))
        XCTAssertTrue(AbsolutePath(longAbsolutePathOverPathMax + #"\2.1"#) >= AbsolutePath(longAbsolutePathOverPathMax + #"\2"#))

        let unParsedLongAbsolutePathOverPathMax = generatePath(260, useUnparsedPrefix: true)
        XCTAssertTrue(AbsolutePath(unParsedLongAbsolutePathOverPathMax + #"\abc"#) < AbsolutePath(unParsedLongAbsolutePathOverPathMax + #"\def"#))
        XCTAssertTrue(AbsolutePath(unParsedLongAbsolutePathOverPathMax + #"\2"#) <= AbsolutePath(unParsedLongAbsolutePathOverPathMax + #"\2.1"#))
        XCTAssertTrue(AbsolutePath(unParsedLongAbsolutePathOverPathMax + #"\3.1"#) > AbsolutePath(unParsedLongAbsolutePathOverPathMax + #"\2"#))
        XCTAssertTrue(AbsolutePath(unParsedLongAbsolutePathOverPathMax + #"\2"#) >= AbsolutePath(unParsedLongAbsolutePathOverPathMax + #"\2"#))
        XCTAssertTrue(AbsolutePath(unParsedLongAbsolutePathOverPathMax + #"\2.1"#) >= AbsolutePath(unParsedLongAbsolutePathOverPathMax + #"\2"#))

        let deviceLongAbsolutePathOverPathMax = generatePath(260, useDevicePrefix: true)
        XCTAssertTrue(AbsolutePath(deviceLongAbsolutePathOverPathMax + #"\abc"#) < AbsolutePath(deviceLongAbsolutePathOverPathMax + #"\def"#))
        XCTAssertTrue(AbsolutePath(deviceLongAbsolutePathOverPathMax + #"\2"#) <= AbsolutePath(deviceLongAbsolutePathOverPathMax + #"\2.1"#))
        XCTAssertTrue(AbsolutePath(deviceLongAbsolutePathOverPathMax + #"\3.1"#) > AbsolutePath(deviceLongAbsolutePathOverPathMax + #"\2"#))
        XCTAssertTrue(AbsolutePath(deviceLongAbsolutePathOverPathMax + #"\2"#) >= AbsolutePath(deviceLongAbsolutePathOverPathMax + #"\2"#))
        XCTAssertTrue(AbsolutePath(deviceLongAbsolutePathOverPathMax + #"\2.1"#) >= AbsolutePath(deviceLongAbsolutePathOverPathMax + #"\2"#))


        #endif
    }

    func testAncestry() {
        #if !os(Windows)
        XCTAssertTrue(AbsolutePath("/a/b/c/d/e/f").isDescendantOfOrEqual(to: AbsolutePath("/a/b/c/d")))
        XCTAssertTrue(AbsolutePath("/a/b/c/d/e/f.swift").isDescendantOfOrEqual(to: AbsolutePath("/a/b/c")))
        XCTAssertTrue(AbsolutePath("/").isDescendantOfOrEqual(to: AbsolutePath("/")))
        XCTAssertTrue(AbsolutePath("/foo/bar").isDescendantOfOrEqual(to: AbsolutePath("/")))
        XCTAssertFalse(AbsolutePath("/foo/bar").isDescendantOfOrEqual(to: AbsolutePath("/foo/bar/baz")))
        XCTAssertFalse(AbsolutePath("/foo/bar").isDescendantOfOrEqual(to: AbsolutePath("/bar")))

        XCTAssertFalse(AbsolutePath("/foo/bar").isDescendant(of: AbsolutePath("/foo/bar")))
        XCTAssertTrue(AbsolutePath("/foo/bar").isDescendant(of: AbsolutePath("/foo")))

        XCTAssertTrue(AbsolutePath("/a/b/c/d").isAncestorOfOrEqual(to: AbsolutePath("/a/b/c/d/e/f")))
        XCTAssertTrue(AbsolutePath("/a/b/c").isAncestorOfOrEqual(to: AbsolutePath("/a/b/c/d/e/f.swift")))
        XCTAssertTrue(AbsolutePath("/").isAncestorOfOrEqual(to: AbsolutePath("/")))
        XCTAssertTrue(AbsolutePath("/").isAncestorOfOrEqual(to: AbsolutePath("/foo/bar")))
        XCTAssertFalse(AbsolutePath("/foo/bar/baz").isAncestorOfOrEqual(to: AbsolutePath("/foo/bar")))
        XCTAssertFalse(AbsolutePath("/bar").isAncestorOfOrEqual(to: AbsolutePath("/foo/bar")))

        XCTAssertFalse(AbsolutePath("/foo/bar").isAncestor(of: AbsolutePath("/foo/bar")))
        XCTAssertTrue(AbsolutePath("/foo").isAncestor(of: AbsolutePath("/foo/bar")))
        #else
        XCTAssertTrue(AbsolutePath(#"C:\a\b\c\d\e\f"#).isDescendantOfOrEqual(to: AbsolutePath(#"C:\a\b\c\d"#)))
        XCTAssertTrue(AbsolutePath(#"C:\a\b\c\d\e\f.swift"#).isDescendantOfOrEqual(to: AbsolutePath(#"C:\a\b\c"#)))
        XCTAssertTrue(AbsolutePath(#"C:\"#).isDescendantOfOrEqual(to: AbsolutePath(#"C:\"#)))
        XCTAssertTrue(AbsolutePath(#"C:\foo\bar"#).isDescendantOfOrEqual(to: AbsolutePath(#"C:\"#)))
        XCTAssertFalse(AbsolutePath(#"C:\foo\bar"#).isDescendantOfOrEqual(to: AbsolutePath(#"C:\foo\bar\baz"#)))
        XCTAssertFalse(AbsolutePath(#"C:\foo\bar"#).isDescendantOfOrEqual(to: AbsolutePath(#"C:\bar"#)))

        XCTAssertTrue(AbsolutePath(#"\\?\C:\a\b\c\d\e\f"#).isDescendantOfOrEqual(to: AbsolutePath(#"C:\a\b\c\d"#)))
        XCTAssertTrue(AbsolutePath(#"\\?\C:\a\b\c\d\e\f.swift"#).isDescendantOfOrEqual(to: AbsolutePath(#"C:\a\b\c"#)))
        XCTAssertTrue(AbsolutePath(#"\\?\C:\"#).isDescendantOfOrEqual(to: AbsolutePath(#"C:\"#)))
        XCTAssertTrue(AbsolutePath(#"\\?\C:\foo\bar"#).isDescendantOfOrEqual(to: AbsolutePath(#"C:\"#)))
        XCTAssertFalse(AbsolutePath(#"\\?\C:\foo\bar"#).isDescendantOfOrEqual(to: AbsolutePath(#"C:\foo\bar\baz"#)))
        XCTAssertFalse(AbsolutePath(#"\\?\C:\foo\bar"#).isDescendantOfOrEqual(to: AbsolutePath(#"C:\bar"#)))

        XCTAssertFalse(AbsolutePath(#"C:\foo\bar"#).isDescendant(of: AbsolutePath(#"C:\foo\bar"#)))
        XCTAssertTrue(AbsolutePath(#"C:\foo\bar"#).isDescendant(of: AbsolutePath(#"C:\foo"#)))

        XCTAssertFalse(AbsolutePath(#"\\?\C:\foo\bar"#).isDescendant(of: AbsolutePath(#"C:\foo\bar"#)))
        XCTAssertTrue(AbsolutePath(#"\\?\C:\foo\bar"#).isDescendant(of: AbsolutePath(#"C:\foo"#)))

        XCTAssertTrue(AbsolutePath(#"C:\a\b\c\d"#).isAncestorOfOrEqual(to: AbsolutePath(#"C:\a\b\c\d\e\f"#)))
        XCTAssertTrue(AbsolutePath(#"C:\a\b\c"#).isAncestorOfOrEqual(to: AbsolutePath(#"C:\a\b\c\d\e\f.swift"#)))
        XCTAssertTrue(AbsolutePath(#"C:\"#).isAncestorOfOrEqual(to: AbsolutePath(#"C:\"#)))
        XCTAssertTrue(AbsolutePath(#"C:\"#).isAncestorOfOrEqual(to: AbsolutePath(#"C:\foo\bar"#)))
        XCTAssertFalse(AbsolutePath(#"C:\foo\bar\baz"#).isAncestorOfOrEqual(to: AbsolutePath(#"C:\foo\bar"#)))
        XCTAssertFalse(AbsolutePath(#"C:\bar"#).isAncestorOfOrEqual(to: AbsolutePath(#"C:\foo\bar"#)))

        XCTAssertTrue(AbsolutePath(#"\\?\C:\a\b\c\d"#).isAncestorOfOrEqual(to: AbsolutePath(#"C:\a\b\c\d\e\f"#)))
        XCTAssertTrue(AbsolutePath(#"\\?\C:\a\b\c"#).isAncestorOfOrEqual(to: AbsolutePath(#"C:\a\b\c\d\e\f.swift"#)))
        XCTAssertTrue(AbsolutePath(#"\\?\C:\"#).isAncestorOfOrEqual(to: AbsolutePath(#"C:\"#)))
        XCTAssertTrue(AbsolutePath(#"\\?\C:\"#).isAncestorOfOrEqual(to: AbsolutePath(#"C:\foo\bar"#)))
        XCTAssertFalse(AbsolutePath(#"\\?\C:\foo\bar\baz"#).isAncestorOfOrEqual(to: AbsolutePath(#"C:\foo\bar"#)))
        XCTAssertFalse(AbsolutePath(#"\\?\C:\bar"#).isAncestorOfOrEqual(to: AbsolutePath(#"C:\foo\bar"#)))

        XCTAssertFalse(AbsolutePath(#"C:\foo\bar"#).isAncestor(of: AbsolutePath(#"C:\foo\bar"#)))
        XCTAssertTrue(AbsolutePath(#"C:\foo"#).isAncestor(of: AbsolutePath(#"C:\foo\bar"#)))

        XCTAssertFalse(AbsolutePath(#"\\?\C:\foo\bar"#).isAncestor(of: AbsolutePath(#"\\?\C:\foo\bar"#)))
        XCTAssertTrue(AbsolutePath(#"\\?\C:\foo"#).isAncestor(of: AbsolutePath(#"\\?\C:\foo\bar"#)))

        // Long/Long Ancestry
        let longAbsolutePathOverPathMax = generatePath(265)
        let longerAbsolutePathOverPathMax = generatePath(300)
        XCTAssertTrue(AbsolutePath(longerAbsolutePathOverPathMax).isDescendant(of: AbsolutePath(longAbsolutePathOverPathMax)))
        XCTAssertTrue(AbsolutePath(longerAbsolutePathOverPathMax).isDescendantOfOrEqual(to: AbsolutePath(longAbsolutePathOverPathMax)))
        XCTAssertTrue(AbsolutePath(longAbsolutePathOverPathMax).isAncestorOfOrEqual(to: AbsolutePath(longerAbsolutePathOverPathMax)))
        XCTAssertTrue(AbsolutePath(longAbsolutePathOverPathMax).isAncestor(of: AbsolutePath(longerAbsolutePathOverPathMax)))

        XCTAssertFalse(AbsolutePath(longerAbsolutePathOverPathMax).isAncestor(of: AbsolutePath(longAbsolutePathOverPathMax)))
        XCTAssertFalse(AbsolutePath(longAbsolutePathOverPathMax).isAncestor(of: AbsolutePath(longAbsolutePathOverPathMax)))
        XCTAssertFalse(AbsolutePath(longAbsolutePathOverPathMax + #"\baz"#).isAncestorOfOrEqual(to: AbsolutePath(longAbsolutePathOverPathMax)))

        // Long/Short to Long Ancestry
        XCTAssertTrue(AbsolutePath(longAbsolutePathOverPathMax).isDescendant(of: AbsolutePath(#"C:\0\1\2"#)))
        XCTAssertTrue(AbsolutePath(longAbsolutePathOverPathMax).isDescendantOfOrEqual(to: AbsolutePath(#"C:\0\1\2"#)))
        XCTAssertTrue(AbsolutePath(#"C:\0\1\2"#).isAncestorOfOrEqual(to: AbsolutePath(longAbsolutePathOverPathMax)))
        XCTAssertTrue(AbsolutePath(#"C:\0\1\2"#).isAncestor(of: AbsolutePath(longAbsolutePathOverPathMax)))

        #endif
    }

    func testAbsolutePathValidation() {
        #if !os(Windows)
        XCTAssertNoThrow(try AbsolutePath(validating: "/a/b/c/d"))

        XCTAssertThrowsError(try AbsolutePath(validating: "~/a/b/d")) { error in
            XCTAssertEqual("\(error)", "invalid absolute path '~/a/b/d'; absolute path must begin with '/'")
        }

        XCTAssertThrowsError(try AbsolutePath(validating: "a/b/d")) { error in
            XCTAssertEqual("\(error)", "invalid absolute path 'a/b/d'")
        }
        #else
        XCTAssertNoThrow(try AbsolutePath(validating: #"C:\a\b\c\d"#))

        XCTAssertThrowsError(try AbsolutePath(validating: #"~\a\b\d"#)) { error in
            XCTAssertEqual("\(error)", #"invalid absolute path '~\a\b\d'"#)
        }

        XCTAssertThrowsError(try AbsolutePath(validating: #"a\b\d"#)) { error in
            XCTAssertEqual("\(error)", #"invalid absolute path 'a\b\d'"#)
        }

        XCTAssertNoThrow(try AbsolutePath(validating: #"\\?\C:\a\b\c\d"#))
        XCTAssertNoThrow(try AbsolutePath(validating: #"\\.\C:\a\b\c\d"#))

        let relativeLongPath = generatePath(265, absolute: false)
        XCTAssertThrowsError(try AbsolutePath(validating: relativeLongPath)) { error in
            XCTAssertEqual("\(error)", "invalid absolute path '\(relativeLongPath)'")
        }

        #endif
    }

    func testRelativePathValidation() {
        #if !os(Windows)
        XCTAssertNoThrow(try RelativePath(validating: "a/b/c/d"))

        XCTAssertThrowsError(try RelativePath(validating: "/a/b/d")) { error in
            XCTAssertEqual("\(error)", "invalid relative path '/a/b/d'; relative path should not begin with '/'")
        }
        #else
        XCTAssertNoThrow(try RelativePath(validating: #"a\b\c\d"#))

        XCTAssertThrowsError(try RelativePath(validating: #"\a\b\d"#)) { error in
            XCTAssertEqual("\(error)", #"invalid relative path '\a\b\d'; relative path should not begin with '\'"#)
        }

        let absoluteLongPath = generatePath(265, absolute: true)
        XCTAssertThrowsError(try RelativePath(validating: absoluteLongPath)) { error in
            XCTAssertEqual("\(error)", "invalid relative path '\(absoluteLongPath)'; relative path should not begin with '\\'")
        }
        #endif
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

        #if os(Windows)
        let isWindowsOS = true
        #else
        let isWindowsOS = false
        #endif

        do {
            let foo = Foo(path: !isWindowsOS ? "/path/to/foo" : #"\path\to\foo"#)
            let data = try JSONEncoder().encode(foo)
            let decodedFoo = try JSONDecoder().decode(Foo.self, from: data)
            XCTAssertEqual(foo, decodedFoo)
        }

        do {
            let foo = Foo(path: !isWindowsOS ? "/path/to/../to/foo" : #"C:\path\to\..\to\foo"#)
            let data = try JSONEncoder().encode(foo)
            let decodedFoo = try JSONDecoder().decode(Foo.self, from: data)
            XCTAssertEqual(foo, decodedFoo)
            XCTAssertEqual(foo.path.pathString, !isWindowsOS ? "/path/to/foo" : #"C:\path\to\foo"#)
            XCTAssertEqual(decodedFoo.path.pathString, !isWindowsOS ? "/path/to/foo" : #"C:\path\to\foo"#)
        }

        do {
            let bar = Bar(path: !isWindowsOS ? "path/to/bar" : #"path/to/bar"#)
            let data = try JSONEncoder().encode(bar)
            let decodedBar = try JSONDecoder().decode(Bar.self, from: data)
            XCTAssertEqual(bar, decodedBar)
        }

        do {
            let bar = Bar(path: !isWindowsOS ? "path/to/../to/bar" : #"path\to\..\to\bar"#)
            let data = try JSONEncoder().encode(bar)
            let decodedBar = try JSONDecoder().decode(Bar.self, from: data)
            XCTAssertEqual(bar, decodedBar)
            XCTAssertEqual(bar.path.pathString, !isWindowsOS ? "path/to/bar" : #"path\to\..\to\bar"#)
            XCTAssertEqual(decodedBar.path.pathString, !isWindowsOS ? "path/to/bar" : #"path\to\..\to\bar"#)
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
            let data = try JSONEncoder().encode(Baz(path: !isWindowsOS ? "/foo" : #"C:\foo"#))
            XCTAssertThrowsError(try JSONDecoder().decode(Bar.self, from: data))
        }
    }

    #if os(Windows)
    func testDiskDesignatorNormalization() {
        XCTAssertEqual(
            AbsolutePath(#"C:\Users\compnerd\AppData\Local\Programs\Swift\Toolchains\0.0.0+Asserts\usr\bin\swiftc.exe"#).pathString,
            #"C:\Users\compnerd\AppData\Local\Programs\Swift\Toolchains\0.0.0+Asserts\usr\bin\swiftc.exe"#
        )
        XCTAssertEqual(
            AbsolutePath(#"c:\Users\compnerd\AppData\Local\Programs\Swift\Toolchains\0.0.0+Asserts\usr\bin\swiftc.exe"#).pathString,
            #"C:\Users\compnerd\AppData\Local\Programs\Swift\Toolchains\0.0.0+Asserts\usr\bin\swiftc.exe"#
        )

        let absoluteLongPath = generatePath(265)
        XCTAssertEqual(
            AbsolutePath(absoluteLongPath).pathString,
            #"\\?\"# + absoluteLongPath
        )
        XCTAssertEqual(
            AbsolutePath(absoluteLongPath.replacingOccurrences(of: "C:", with: "c:")).pathString,
            #"\\?\"# + absoluteLongPath
        )
    }
    #endif
}
