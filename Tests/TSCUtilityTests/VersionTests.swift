/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import struct TSCUtility.Version
import enum TSCUtility.VersionError
import XCTest

class VersionTests: XCTestCase {

    func testVersionNonthrowingInitialization() {
        let v0 = Version(0, 0, 0, prereleaseIdentifiers: [], buildMetadataIdentifiers: [])
        XCTAssertEqual(v0.minor, 0)
        XCTAssertEqual(v0.minor, 0)
        XCTAssertEqual(v0.patch, 0)
        XCTAssertEqual(v0.prereleaseIdentifiers, [])
        XCTAssertEqual(v0.buildMetadataIdentifiers, [])

        let v1 = Version(1, 1, 2, prereleaseIdentifiers: ["3", "5"], buildMetadataIdentifiers: ["8", "13"])
        XCTAssertEqual(v1.minor, 1)
        XCTAssertEqual(v1.minor, 1)
        XCTAssertEqual(v1.patch, 2)
        XCTAssertEqual(v1.prereleaseIdentifiers, ["3", "5"])
        XCTAssertEqual(v1.buildMetadataIdentifiers, ["8", "13"])

        XCTAssertEqual(
            Version(3, 5, 8),
            Version(3, 5, 8, prereleaseIdentifiers: [], buildMetadataIdentifiers: [])
        )

        XCTAssertEqual(
            Version(13, 21, 34, prereleaseIdentifiers: ["55"]),
            Version(13, 21, 34, prereleaseIdentifiers: ["55"], buildMetadataIdentifiers: [])
        )

        XCTAssertEqual(
            Version(89, 144, 233, buildMetadataIdentifiers: ["377"]),
            Version(89, 144, 233, prereleaseIdentifiers: [], buildMetadataIdentifiers: ["377"])
        )
    }

    func testVersionThrowingInitialization() {

        // MARK: Well-formed version core

        XCTAssertNoThrow(try Version(versionString: "0.0.0"))
        XCTAssertEqual(try! Version(versionString: "0.0.0"), Version(0, 0, 0))

        XCTAssertNoThrow(try Version(versionString: "1.1.2"))
        XCTAssertEqual(try! Version(versionString: "1.1.2"), Version(1, 1, 2))

        XCTAssertNoThrow(try Version(versionString: "0.0.0", usesLenientParsing: false))
        XCTAssertEqual(try! Version(versionString: "0.0.0", usesLenientParsing: false), Version(0, 0, 0))

        XCTAssertNoThrow(try Version(versionString: "1.1.2"))
        XCTAssertEqual(try! Version(versionString: "1.1.2"), Version(1, 1, 2))

        XCTAssertNoThrow(try Version(versionString: "0.0.0", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "0.0.0", usesLenientParsing: true), Version(0, 0, 0))

        XCTAssertNoThrow(try Version(versionString: "1.1.2", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "1.1.2", usesLenientParsing: true), Version(1, 1, 2))

        XCTAssertNoThrow(try Version(versionString: "0.0", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "0.0.0", usesLenientParsing: true), Version(0, 0, 0))

        XCTAssertNoThrow(try Version(versionString: "1.2", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "1.2", usesLenientParsing: true), Version(1, 2, 0))

        // MARK: Malformed version core

        XCTAssertThrowsError(try Version(versionString: "3")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["3"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core '3'")
        }

        XCTAssertThrowsError(try Version(versionString: "3", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["3"], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 2 identifiers in version core '3'")
        }

        XCTAssertThrowsError(try Version(versionString: "3 5")) { error in
            // checking for version core identifier count comes before checking for alpha-numerical characters
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["3 5"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core '3 5'")
        }

        XCTAssertThrowsError(try Version(versionString: "3 5", usesLenientParsing: true)) { error in
            // checking for version core identifier count comes before checking for alpha-numerical characters
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["3 5"], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 2 identifiers in version core '3 5'")
        }

        XCTAssertThrowsError(try Version(versionString: "5.8")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["5", "8"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core '5.8'")
        }

        XCTAssertThrowsError(try Version(versionString: "-5.8.13")) { error in
            // the version core is considered empty because of the leading '-'
            // everything after the first '-' is considered as the pre-release information (until the first '+', which doesn't exist in this version string)
            // the version core is NOT considered missing, because it has 1 identifier, despite the identifier being empty
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount([""], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core ''")
        }

        XCTAssertThrowsError(try Version(versionString: "-5.8.13", usesLenientParsing: true)) { error in
            // the version core is considered empty because of the leading '-'
            // everything after the first '-' is considered as the pre-release information (until the first '+', which doesn't exist in this version string)
            // the version core is NOT considered missing, because it has 1 identifier, despite the identifier being empty
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount([""], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 2 identifiers in version core ''")
        }

        XCTAssertThrowsError(try Version(versionString: "8.-13.21")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["8", ""], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core '8.'")
        }

        XCTAssertThrowsError(try Version(versionString: "8.-13.21", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["8", ""]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "empty identifiers in version core '8.'")
        }

        XCTAssertThrowsError(try Version(versionString: "13.21.-34")) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["13", "21", ""]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "empty identifiers in version core '13.21.'")
        }

        XCTAssertThrowsError(try Version(versionString: "13.21.-34", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["13", "21", ""]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "empty identifiers in version core '13.21.'")
        }

        XCTAssertThrowsError(try Version(versionString: "-0.0.0")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount([""], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core ''")
        }

        XCTAssertThrowsError(try Version(versionString: "-0.0.0", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount([""], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 2 identifiers in version core ''")
        }

        XCTAssertThrowsError(try Version(versionString: "0.-0.0")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["0", ""], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core '0.'")
        }

        XCTAssertThrowsError(try Version(versionString: "0.-0.0", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["0", ""]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "empty identifiers in version core '0.'")
        }

        XCTAssertThrowsError(try Version(versionString: "0.0.O")) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["0", "0", "O"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifier 'O'")
        }

        XCTAssertThrowsError(try Version(versionString: "0.0.O", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["0", "0", "O"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifier 'O'")
        }

        XCTAssertThrowsError(try Version(versionString: "1.l1.O")) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["1", "l1", "O"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifiers 'l1', 'O'")
        }

        XCTAssertThrowsError(try Version(versionString: "1.l1.O", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["1", "l1", "O"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifiers 'l1', 'O'")
        }

        XCTAssertThrowsError(try Version(versionString: "21.34.55.89")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["21", "34", "55", "89"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "more than 3 identifiers in version core '21.34.55.89'")
        }

        XCTAssertThrowsError(try Version(versionString: "21.34.55.89", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["21", "34", "55", "89"], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "more than 3 identifiers in version core '21.34.55.89'")
        }

        XCTAssertThrowsError(try Version(versionString: "6 x 9 = 42")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["6 x 9 = 42"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core '6 x 9 = 42'")
        }

        XCTAssertThrowsError(try Version(versionString: "6 x 9 = 42", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["6 x 9 = 42"], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 2 identifiers in version core '6 x 9 = 42'")
        }

        XCTAssertThrowsError(try Version(versionString: "forty two")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["forty two"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core 'forty two'")
        }

        XCTAssertThrowsError(try Version(versionString: "forty two", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["forty two"], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 2 identifiers in version core 'forty two'")
        }

        XCTAssertThrowsError(try Version(versionString: "一点二点三")) { error in
            guard let error = error as? VersionError, case .nonASCIIVersionString("一点二点三") = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-ASCII characters in version string '一点二点三'")
        }

        XCTAssertThrowsError(try Version(versionString: "一点二点三", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonASCIIVersionString("一点二点三") = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-ASCII characters in version string '一点二点三'")
        }

        // MARK: Well-formed version core, well-formed pre-release identifiers

        XCTAssertNoThrow(try Version(versionString: "0.0.0-pre-alpha"))
        XCTAssertEqual(try! Version(versionString: "0.0.0-pre-alpha"), Version(0, 0, 0, prereleaseIdentifiers: ["pre-alpha"]))

        XCTAssertNoThrow(try Version(versionString: "0.0.0-pre-alpha", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "0.0.0-pre-alpha", usesLenientParsing: true), Version(0, 0, 0, prereleaseIdentifiers: ["pre-alpha"]))

        XCTAssertNoThrow(try Version(versionString: "0.0-pre-alpha", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "0.0-pre-alpha", usesLenientParsing: true), Version(0, 0, 0, prereleaseIdentifiers: ["pre-alpha"]))

        XCTAssertNoThrow(try Version(versionString: "55.89.144-beta.1"))
        XCTAssertEqual(try! Version(versionString: "55.89.144-beta.1"), Version(55, 89, 144, prereleaseIdentifiers: ["beta", "1"]))

        XCTAssertNoThrow(try Version(versionString: "55.89.144-beta.1", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "55.89.144-beta.1", usesLenientParsing: true), Version(55, 89, 144, prereleaseIdentifiers: ["beta", "1"]))

        XCTAssertNoThrow(try Version(versionString: "55.89-beta.1", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "55.89-beta.1", usesLenientParsing: true), Version(55, 89, 0, prereleaseIdentifiers: ["beta", "1"]))

        XCTAssertNoThrow(try Version(versionString: "89.144.233-a.whole..lot.of.pre-release.identifiers"))
        XCTAssertEqual(try! Version(versionString: "89.144.233-a.whole..lot.of.pre-release.identifiers"), Version(89, 144, 233, prereleaseIdentifiers: ["a", "whole", "", "lot", "of", "pre-release", "identifiers"]))

        XCTAssertNoThrow(try Version(versionString: "89.144.233-a.whole..lot.of.pre-release.identifiers", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "89.144.233-a.whole..lot.of.pre-release.identifiers", usesLenientParsing: true), Version(89, 144, 233, prereleaseIdentifiers: ["a", "whole", "", "lot", "of", "pre-release", "identifiers"]))

        XCTAssertNoThrow(try Version(versionString: "89.144-a.whole..lot.of.pre-release.identifiers", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "89.144-a.whole..lot.of.pre-release.identifiers", usesLenientParsing: true), Version(89, 144, 0, prereleaseIdentifiers: ["a", "whole", "", "lot", "of", "pre-release", "identifiers"]))

        XCTAssertNoThrow(try Version(versionString: "144.233.377-"))
        XCTAssertEqual(try! Version(versionString: "144.233.377-"), Version(144, 233, 377, prereleaseIdentifiers: [""]))

        XCTAssertNoThrow(try Version(versionString: "144.233.377-", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "144.233.377-", usesLenientParsing: true), Version(144, 233, 377, prereleaseIdentifiers: [""]))

        XCTAssertNoThrow(try Version(versionString: "144.233-", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "144.233-", usesLenientParsing: true), Version(144, 233, 0, prereleaseIdentifiers: [""]))

        // MARK: Well-formed version core, malformed pre-release identifiers

        XCTAssertThrowsError(try Version(versionString: "233.377.610-hello world")) { error in
            guard let error = error as? VersionError, case .nonAlphaNumerHyphenalPrereleaseIdentifiers(["hello world"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "characters other than alpha-numerics and hyphens in pre-release identifier 'hello world'")
        }

        XCTAssertThrowsError(try Version(versionString: "233.377.610-hello world", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonAlphaNumerHyphenalPrereleaseIdentifiers(["hello world"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "characters other than alpha-numerics and hyphens in pre-release identifier 'hello world'")
        }

        XCTAssertThrowsError(try Version(versionString: "1.2.3-测试版")) { error in
            guard let error = error as? VersionError, case .nonASCIIVersionString("1.2.3-测试版") = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-ASCII characters in version string '1.2.3-测试版'")
        }

        XCTAssertThrowsError(try Version(versionString: "1.2.3-测试版", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonASCIIVersionString("1.2.3-测试版") = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-ASCII characters in version string '1.2.3-测试版'")
        }

        // MARK: Malformed version core, well-formed pre-release identifiers

        XCTAssertThrowsError(try Version(versionString: "987-Hello.world--------")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["987"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core '987'")
        }

        XCTAssertThrowsError(try Version(versionString: "987-Hello.world--------", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["987"], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 2 identifiers in version core '987'")
        }

        XCTAssertThrowsError(try Version(versionString: "987.1597-half-life.3")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["987", "1597"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core '987.1597'")
        }

        XCTAssertThrowsError(try Version(versionString: "1597.2584.4181.6765-a.whole.lot.of.pre-release.identifiers")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["1597", "2584", "4181", "6765"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "more than 3 identifiers in version core '1597.2584.4181.6765'")
        }

        XCTAssertThrowsError(try Version(versionString: "1597.2584.4181.6765-a.whole.lot.of.pre-release.identifiers", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["1597", "2584", "4181", "6765"], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "more than 3 identifiers in version core '1597.2584.4181.6765'")
        }

        XCTAssertThrowsError(try Version(versionString: "6 x 9 = 42-")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["6 x 9 = 42"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core '6 x 9 = 42'")
        }

        XCTAssertThrowsError(try Version(versionString: "6 x 9 = 42-", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["6 x 9 = 42"], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 2 identifiers in version core '6 x 9 = 42'")
        }

        XCTAssertThrowsError(try Version(versionString: "forty-two")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["forty"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core 'forty'")
        }

        XCTAssertThrowsError(try Version(versionString: "forty-two", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["forty"], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 2 identifiers in version core 'forty'")
        }

        XCTAssertThrowsError(try Version(versionString: "l.2.3")) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["l", "2", "3"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifier 'l'")
        }

        XCTAssertThrowsError(try Version(versionString: "l.2.3", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["l", "2", "3"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifier 'l'")
        }

        XCTAssertThrowsError(try Version(versionString: "l.b.3")) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["l", "b", "3"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifiers 'l', 'b'")
        }

        XCTAssertThrowsError(try Version(versionString: "l.b.3", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["l", "b", "3"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifiers 'l', 'b'")
        }

        XCTAssertThrowsError(try Version(versionString: "l.2.З")) { error in
            guard let error = error as? VersionError, case .nonASCIIVersionString("l.2.З") = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-ASCII characters in version string 'l.2.З'")
        }

        XCTAssertThrowsError(try Version(versionString: "l.2.З", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonASCIIVersionString("l.2.З") = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-ASCII characters in version string 'l.2.З'")
        }

        XCTAssertThrowsError(try Version(versionString: "一点二点三-beta")) { error in
            guard let error = error as? VersionError, case .nonASCIIVersionString("一点二点三-beta") = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-ASCII characters in version string '一点二点三-beta'")
        }

        XCTAssertThrowsError(try Version(versionString: "一点二点三-beta", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonASCIIVersionString("一点二点三-beta") = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-ASCII characters in version string '一点二点三-beta'")
        }

        // MARK: Well-formed version core, well-formed build metadata identifiers

        XCTAssertNoThrow(try Version(versionString: "0.0.0+some-metadata"))
        XCTAssertEqual(try! Version(versionString: "0.0.0+some-metadata"), Version(0, 0, 0, buildMetadataIdentifiers: ["some-metadata"]))

        XCTAssertNoThrow(try Version(versionString: "0.0.0+some-metadata", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "0.0.0+some-metadata", usesLenientParsing: true), Version(0, 0, 0, buildMetadataIdentifiers: ["some-metadata"]))

        XCTAssertNoThrow(try Version(versionString: "0.0+some-metadata", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "0.0+some-metadata", usesLenientParsing: true), Version(0, 0, 0, buildMetadataIdentifiers: ["some-metadata"]))

        XCTAssertNoThrow(try Version(versionString: "4181.6765.10946+more.meta..more.data"))
        XCTAssertEqual(try! Version(versionString: "4181.6765.10946+more.meta..more.data"), Version(4181, 6765, 10946, buildMetadataIdentifiers: ["more", "meta", "", "more", "data"]))

        XCTAssertNoThrow(try Version(versionString: "4181.6765.10946+more.meta..more.data", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "4181.6765.10946+more.meta..more.data", usesLenientParsing: true), Version(4181, 6765, 10946, buildMetadataIdentifiers: ["more", "meta", "", "more", "data"]))

        XCTAssertNoThrow(try Version(versionString: "4181.6765+more.meta..more.data", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "4181.6765+more.meta..more.data", usesLenientParsing: true), Version(4181, 6765, 0, buildMetadataIdentifiers: ["more", "meta", "", "more", "data"]))

        XCTAssertNoThrow(try Version(versionString: "6765.10946.17711+-a-very--long---build-----metadata--------identifier-------------with---------------------many----------------------------------hyphens-------------------------------------------------------"))
        XCTAssertEqual(try! Version(versionString: "6765.10946.17711+-a-very--long---build-----metadata--------identifier-------------with---------------------many----------------------------------hyphens-------------------------------------------------------"), Version(6765, 10946, 17711, buildMetadataIdentifiers: ["-a-very--long---build-----metadata--------identifier-------------with---------------------many----------------------------------hyphens-------------------------------------------------------"]))

        XCTAssertNoThrow(try Version(versionString: "6765.10946.17711+-a-very--long---build-----metadata--------identifier-------------with---------------------many----------------------------------hyphens-------------------------------------------------------", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "6765.10946.17711+-a-very--long---build-----metadata--------identifier-------------with---------------------many----------------------------------hyphens-------------------------------------------------------", usesLenientParsing: true), Version(6765, 10946, 17711, buildMetadataIdentifiers: ["-a-very--long---build-----metadata--------identifier-------------with---------------------many----------------------------------hyphens-------------------------------------------------------"]))

        XCTAssertNoThrow(try Version(versionString: "6765.10946+-a-very--long---build-----metadata--------identifier-------------with---------------------many----------------------------------hyphens-------------------------------------------------------", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "6765.10946+-a-very--long---build-----metadata--------identifier-------------with---------------------many----------------------------------hyphens-------------------------------------------------------", usesLenientParsing: true), Version(6765, 10946, 0, buildMetadataIdentifiers: ["-a-very--long---build-----metadata--------identifier-------------with---------------------many----------------------------------hyphens-------------------------------------------------------"]))

        XCTAssertNoThrow(try Version(versionString: "10946.17711.28657+"))
        XCTAssertEqual(try! Version(versionString: "10946.17711.28657+"), Version(10946, 17711, 28657, buildMetadataIdentifiers: [""]))

        XCTAssertNoThrow(try Version(versionString: "10946.17711.28657+", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "10946.17711.28657+", usesLenientParsing: true), Version(10946, 17711, 28657, buildMetadataIdentifiers: [""]))

        XCTAssertNoThrow(try Version(versionString: "10946.17711+", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "10946.17711+", usesLenientParsing: true), Version(10946, 17711, 0, buildMetadataIdentifiers: [""]))

        // MARK: Well-formed version core, malformed build metadata identifiers

        XCTAssertThrowsError(try Version(versionString: "17711.28657.46368+hello world.hello-.-world")) { error in
            guard let error = error as? VersionError, case .nonAlphaNumerHyphenalBuildMetadataIdentifiers(["hello world", "hello-", "-world"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "characters other than alpha-numerics and hyphens in build metadata identifier 'hello world'")
        }

        XCTAssertThrowsError(try Version(versionString: "17711.28657.46368+hello world.hello-.-world", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonAlphaNumerHyphenalBuildMetadataIdentifiers(["hello world", "hello-", "-world"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "characters other than alpha-numerics and hyphens in build metadata identifier 'hello world'")
        }

        XCTAssertThrowsError(try Version(versionString: "28657.46368.75025+hello+world.hello world")) { error in
            guard let error = error as? VersionError, case .nonAlphaNumerHyphenalBuildMetadataIdentifiers(["hello+world", "hello world"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "characters other than alpha-numerics and hyphens in build metadata identifiers 'hello+world', 'hello world'")
        }

        XCTAssertThrowsError(try Version(versionString: "28657.46368.75025+hello+world.hello world", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonAlphaNumerHyphenalBuildMetadataIdentifiers(["hello+world", "hello world"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "characters other than alpha-numerics and hyphens in build metadata identifiers 'hello+world', 'hello world'")
        }

        // MARK: Malformed version core, well-formed build metadata identifiers

        XCTAssertThrowsError(try Version(versionString: "121393+Hello.world--------")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["121393"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core '121393'")
        }

        XCTAssertThrowsError(try Version(versionString: "121393+Hello.world--------", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["121393"], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 2 identifiers in version core '121393'")
        }

        XCTAssertThrowsError(try Version(versionString: "121393.196418+half-life.3")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["121393", "196418"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core '121393.196418'")
        }

        XCTAssertThrowsError(try Version(versionString: "196418.317811.514229.832040+a.whole.lot.of.build.metadata.identifiers")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["196418", "317811", "514229", "832040"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "more than 3 identifiers in version core '196418.317811.514229.832040'")
        }

        XCTAssertThrowsError(try Version(versionString: "196418.317811.514229.832040+a.whole.lot.of.build.metadata.identifiers", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["196418", "317811", "514229", "832040"], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "more than 3 identifiers in version core '196418.317811.514229.832040'")
        }

        XCTAssertThrowsError(try Version(versionString: "196418.317811.514229.83204O+a.whole.lot.of.build.metadata.identifiers")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["196418", "317811", "514229", "83204O"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "more than 3 identifiers in version core '196418.317811.514229.83204O'")
        }

        XCTAssertThrowsError(try Version(versionString: "196418.317811.514229.83204O+a.whole.lot.of.build.metadata.identifiers", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["196418", "317811", "514229", "83204O"], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "more than 3 identifiers in version core '196418.317811.514229.83204O'")
        }

        XCTAssertThrowsError(try Version(versionString: "196418.317811.83204O+a.whole.lot.of.build.metadata.identifiers")) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["196418", "317811", "83204O"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifier '83204O'")
        }

        XCTAssertThrowsError(try Version(versionString: "196418.317811.83204O+a.whole.lot.of.build.metadata.identifiers", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["196418", "317811", "83204O"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifier '83204O'")
        }

        XCTAssertThrowsError(try Version(versionString: "abc.def.ghi+a.whole.lot.of.build.metadata.identifiers")) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["abc", "def", "ghi"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifiers 'abc', 'def', 'ghi'")
        }

        XCTAssertThrowsError(try Version(versionString: "abc.def.ghi+a.whole.lot.of.build.metadata.identifiers", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["abc", "def", "ghi"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifiers 'abc', 'def', 'ghi'")
        }

        XCTAssertThrowsError(try Version(versionString: "6 x 9 = 42+")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["6 x 9 = 42"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core '6 x 9 = 42'")
        }

        XCTAssertThrowsError(try Version(versionString: "6 x 9 = 42+", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["6 x 9 = 42"], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 2 identifiers in version core '6 x 9 = 42'")
        }

        XCTAssertThrowsError(try Version(versionString: "forty two+a-very-long-build-metadata-identifier-with-many-hyphens")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["forty two"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core 'forty two'")
        }

        XCTAssertThrowsError(try Version(versionString: "forty two+a-very-long-build-metadata-identifier-with-many-hyphens", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["forty two"], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 2 identifiers in version core 'forty two'")
        }

        XCTAssertThrowsError(try Version(versionString: "一.二.三+build.metadata")) { error in
            guard let error = error as? VersionError, case .nonASCIIVersionString("一.二.三+build.metadata") = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-ASCII characters in version string '一.二.三+build.metadata'")
        }

        XCTAssertThrowsError(try Version(versionString: "一.二.三+build.metadata", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonASCIIVersionString("一.二.三+build.metadata") = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-ASCII characters in version string '一.二.三+build.metadata'")
        }

        // MARK: Well-formed version core, well-formed pre-release identifiers, well-formed build metadata identifiers

        XCTAssertNoThrow(try Version(versionString: "0.0.0-beta.-42+42-42.42"))
        XCTAssertEqual(try! Version(versionString: "0.0.0-beta.-42+42-42.42"), Version(0, 0, 0, prereleaseIdentifiers: ["beta", "-42"], buildMetadataIdentifiers: ["42-42", "42"]))

        XCTAssertNoThrow(try Version(versionString: "0.0.0-beta.-42+42-42.42", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "0.0.0-beta.-42+42-42.42", usesLenientParsing: true), Version(0, 0, 0, prereleaseIdentifiers: ["beta", "-42"], buildMetadataIdentifiers: ["42-42", "42"]))

        XCTAssertNoThrow(try Version(versionString: "0.0-beta.-42+42-42.42", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "0.0-beta.-42+42-42.42", usesLenientParsing: true), Version(0, 0, 0, prereleaseIdentifiers: ["beta", "-42"], buildMetadataIdentifiers: ["42-42", "42"]))

        XCTAssertNoThrow(try Version(versionString: "1.2.3-beta.-24+abc-xyz.42"))
        XCTAssertEqual(try! Version(versionString: "1.2.3-beta.-24+abc-xyz.42"), Version(1, 2, 3, prereleaseIdentifiers: ["beta", "-24"], buildMetadataIdentifiers: ["abc-xyz", "42"]))

        XCTAssertNoThrow(try Version(versionString: "1.2.3-beta.-24+abc-xyz.42", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "1.2.3-beta.-24+abc-xyz.42", usesLenientParsing: true), Version(1, 2, 3, prereleaseIdentifiers: ["beta", "-24"], buildMetadataIdentifiers: ["abc-xyz", "42"]))

        XCTAssertNoThrow(try Version(versionString: "1.2-beta.-24+abc-xyz.42", usesLenientParsing: true))
        XCTAssertEqual(try! Version(versionString: "1.2-beta.-24+abc-xyz.42", usesLenientParsing: true), Version(1, 2, 0, prereleaseIdentifiers: ["beta", "-24"], buildMetadataIdentifiers: ["abc-xyz", "42"]))


        // MARK: Well-formed version core, well-formed pre-release identifiers, malformed build metadata identifiers

        XCTAssertThrowsError(try Version(versionString: "514229.832040.1346269-beta1+  ")) { error in
            guard let error = error as? VersionError, case .nonAlphaNumerHyphenalBuildMetadataIdentifiers(["  "]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "characters other than alpha-numerics and hyphens in build metadata identifier '  '")
        }

        XCTAssertThrowsError(try Version(versionString: "514229.832040.1346269-beta1+  ", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonAlphaNumerHyphenalBuildMetadataIdentifiers(["  "]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "characters other than alpha-numerics and hyphens in build metadata identifier '  '")
        }

        // MARK: Well-formed version core, malformed pre-release identifiers, well-formed build metadata identifiers

        XCTAssertThrowsError(try Version(versionString: "832040.1346269.2178309-beta 1.-+-")) { error in
            guard let error = error as? VersionError, case .nonAlphaNumerHyphenalPrereleaseIdentifiers(["beta 1", "-"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "characters other than alpha-numerics and hyphens in pre-release identifier 'beta 1'")
        }

        XCTAssertThrowsError(try Version(versionString: "832040.1346269.2178309-beta 1.-+-", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonAlphaNumerHyphenalPrereleaseIdentifiers(["beta 1", "-"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "characters other than alpha-numerics and hyphens in pre-release identifier 'beta 1'")
        }

        // MARK: Well-formed version core, malformed pre-release identifiers, malformed build metadata identifiers

        // pre-release is diagnosed before build metadata is
        XCTAssertThrowsError(try Version(versionString: "1346269.2178309.3524578-beta 1++")) { error in
            guard let error = error as? VersionError, case .nonAlphaNumerHyphenalPrereleaseIdentifiers(["beta 1"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "characters other than alpha-numerics and hyphens in pre-release identifier 'beta 1'")
        }

        XCTAssertThrowsError(try Version(versionString: "1346269.2178309.3524578-beta 1++", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonAlphaNumerHyphenalPrereleaseIdentifiers(["beta 1"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "characters other than alpha-numerics and hyphens in pre-release identifier 'beta 1'")
        }

        // MARK: malformed version core, well-formed pre-release identifiers, well-formed build metadata identifiers

        XCTAssertThrowsError(try Version(versionString: " 832040.1346269.3524578-beta1+abc")) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers([" 832040", "1346269", "3524578"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifier ' 832040'")
        }

        XCTAssertThrowsError(try Version(versionString: " 832040.1346269.3524578-beta1+abc", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers([" 832040", "1346269", "3524578"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifier ' 832040'")
        }

        // MARK: malformed version core, well-formed pre-release identifiers, malformed build metadata identifiers

        XCTAssertThrowsError(try Version(versionString: "l346269.3524578.5702887-beta1+😀")) { error in
            guard let error = error as? VersionError, case .nonASCIIVersionString("l346269.3524578.5702887-beta1+😀") = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-ASCII characters in version string 'l346269.3524578.5702887-beta1+😀'")
        }

        XCTAssertThrowsError(try Version(versionString: "l346269.3524578.5702887-beta1+😀", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonASCIIVersionString("l346269.3524578.5702887-beta1+😀") = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-ASCII characters in version string 'l346269.3524578.5702887-beta1+😀'")
        }

        // version core is diagnosed before build metadata is
        XCTAssertThrowsError(try Version(versionString: "l346269.abc.OOO-beta1+++.+.+")) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["l346269", "abc", "OOO"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifiers 'l346269', 'abc', 'OOO'")
        }

        XCTAssertThrowsError(try Version(versionString: "l346269.abc.OOO-beta1+++.+.+", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["l346269", "abc", "OOO"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifiers 'l346269', 'abc', 'OOO'")
        }

        // MARK: malformed version core, malformed pre-release identifiers, well-formed build metadata identifiers

        // version core is diagnosed before pre-release is
        XCTAssertThrowsError(try Version(versionString: "352A578.5702887.9227465-beta!@#$%^&*1+asdfghjkl123456789")) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["352A578", "5702887", "9227465"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifier '352A578'")
        }

        XCTAssertThrowsError(try Version(versionString: "352A578.5702887.9227465-beta!@#$%^&*1+asdfghjkl123456789", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonNumericalOrEmptyVersionCoreIdentifiers(["352A578", "5702887", "9227465"]) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-numerical characters in version core identifier '352A578'")
        }


        // MARK: malformed version core, malformed pre-release identifiers, malformed build metadata identifiers

        XCTAssertThrowsError(try Version(versionString: "5702887.9227465-bètá1+±")) { error in
            guard let error = error as? VersionError, case .nonASCIIVersionString("5702887.9227465-bètá1+±") = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-ASCII characters in version string '5702887.9227465-bètá1+±'")
        }

        XCTAssertThrowsError(try Version(versionString: "5702887.9227465-bètá1+±", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .nonASCIIVersionString("5702887.9227465-bètá1+±") = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "non-ASCII characters in version string '5702887.9227465-bètá1+±'")
        }

        XCTAssertThrowsError(try Version(versionString: "5702887.9227465-bet@.1!+met@.d@t@")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["5702887", "9227465"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core '5702887.9227465'")
        }

        XCTAssertThrowsError(try Version(versionString: "5702887-bet@.1!+met@.d@t@")) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["5702887"], usesLenientParsing: false) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 3 identifiers in version core '5702887'")
        }

        XCTAssertThrowsError(try Version(versionString: "5702887-bet@.1!+met@.d@t@", usesLenientParsing: true)) { error in
            guard let error = error as? VersionError, case .invalidVersionCoreIdentifiersCount(["5702887"], usesLenientParsing: true) = error else {
                XCTFail()
                return
            }
            XCTAssertEqual(error.description, "fewer than 2 identifiers in version core '5702887'")
        }

    }

    func testAdditionalLenientVersionStringParsing() {
        XCTAssertEqual(try! Version(versionString: "1.2", usesLenientParsing: true), Version("1.2.0"))
        XCTAssertEqual(try? Version(versionString: "1", usesLenientParsing: true), nil)
        XCTAssertEqual(try? Version(versionString: "1.2", usesLenientParsing: false), nil)
    }

    // Don't refactor out either `XCTAssertGreaterThan` or `XCTAssertFalse(<)`.
    // The latter may seem redundant, but it tests a different thing.
    // `XCTAssertGreaterThan` asserts that the "true" path of `>` works, which implies that the "true" path of `<` works. However, it doesn't tests the "false" path.
    // `XCTAssertFalse(<)` asserts that the "false" path of `<` works.
    func testVersionComparison() {

        // MARK: version core vs. version core

        XCTAssertGreaterThan(Version(2, 1, 1), Version(1, 2, 3))
        XCTAssertGreaterThan(Version(1, 3, 1), Version(1, 2, 3))
        XCTAssertGreaterThan(Version(1, 2, 4), Version(1, 2, 3))
        
        XCTAssertFalse(Version(2, 1, 1) < Version(1, 2, 3))
        XCTAssertFalse(Version(1, 3, 1) < Version(1, 2, 3))
        XCTAssertFalse(Version(1, 2, 4) < Version(1, 2, 3))

        // MARK: version core vs. version core + pre-release

        XCTAssertGreaterThan(Version(1, 2, 3), Version(1, 2, 3, prereleaseIdentifiers: [""]))
        XCTAssertGreaterThan(Version(1, 2, 3), Version(1, 2, 3, prereleaseIdentifiers: ["beta"]))
        XCTAssertLessThan(Version(1, 2, 2), Version(1, 2, 3, prereleaseIdentifiers: ["beta"]))
        
        XCTAssertFalse(Version(1, 2, 3) < Version(1, 2, 3, prereleaseIdentifiers: [""]))
        XCTAssertFalse(Version(1, 2, 3) < Version(1, 2, 3, prereleaseIdentifiers: ["beta"]))

        // MARK: version core + pre-release vs. version core + pre-release

        XCTAssertEqual(Version(1, 2, 3, prereleaseIdentifiers: [""]), Version(1, 2, 3, prereleaseIdentifiers: [""]))

        XCTAssertEqual(Version(1, 2, 3, prereleaseIdentifiers: ["beta"]), Version(1, 2, 3, prereleaseIdentifiers: ["beta"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["alpha"]), Version(1, 2, 3, prereleaseIdentifiers: ["beta"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["alpha1"]), Version(1, 2, 3, prereleaseIdentifiers: ["alpha2"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["alpha"]), Version(1, 2, 3, prereleaseIdentifiers: ["alpha-"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["beta", "alpha"]), Version(1, 2, 3, prereleaseIdentifiers: ["beta", "beta"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["alpha", "beta"]), Version(1, 2, 3, prereleaseIdentifiers: ["beta", "alpha"]))

        XCTAssertEqual(Version(1, 2, 3, prereleaseIdentifiers: ["1"]), Version(1, 2, 3, prereleaseIdentifiers: ["1"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["1"]), Version(1, 2, 3, prereleaseIdentifiers: ["2"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["1", "1"]), Version(1, 2, 3, prereleaseIdentifiers: ["1", "2"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["1", "2"]), Version(1, 2, 3, prereleaseIdentifiers: ["2", "1"]))

        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["123"]), Version(1, 2, 3, prereleaseIdentifiers: ["123alpha"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["223"]), Version(1, 2, 3, prereleaseIdentifiers: ["123alpha"]))

        // MARK: version core vs. version core + build metadata

        XCTAssertEqual(Version(1, 2, 3), Version(1, 2, 3, buildMetadataIdentifiers: [""]))
        XCTAssertEqual(Version(1, 2, 3), Version(1, 2, 3, buildMetadataIdentifiers: ["beta"]))
        XCTAssertLessThan(Version(1, 2, 2), Version(1, 2, 3, buildMetadataIdentifiers: ["beta"]))

        // MARK: version core + pre-release vs. version core + build metadata

        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: [""]), Version(1, 2, 3, buildMetadataIdentifiers: [""]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["beta"]), Version(1, 2, 3, buildMetadataIdentifiers: ["alpha"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["alpha"]), Version(1, 2, 3, buildMetadataIdentifiers: ["beta"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["beta"]), Version(1, 2, 3, buildMetadataIdentifiers: ["beta"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["alpha"]), Version(1, 2, 3, buildMetadataIdentifiers: ["alpha-"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["123"]), Version(1, 2, 3, buildMetadataIdentifiers: ["123alpha"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["223"]), Version(1, 2, 3, buildMetadataIdentifiers: ["123alpha"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["123alpha"]), Version(1, 2, 3, buildMetadataIdentifiers: ["123"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["123alpha"]), Version(1, 2, 3, buildMetadataIdentifiers: ["223"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["123alpha"]), Version(1, 2, 3, buildMetadataIdentifiers: ["223"]))
        XCTAssertLessThan(Version(1, 2, 3, prereleaseIdentifiers: ["alpha"]), Version(1, 2, 3, buildMetadataIdentifiers: ["beta"]))
        XCTAssertGreaterThan(Version(2, 2, 3, prereleaseIdentifiers: [""]), Version(1, 2, 3, buildMetadataIdentifiers: [""]))
        XCTAssertGreaterThan(Version(1, 3, 3, prereleaseIdentifiers: ["alpha"]), Version(1, 2, 3, buildMetadataIdentifiers: ["beta"]))
        XCTAssertGreaterThan(Version(1, 2, 4, prereleaseIdentifiers: ["223"]), Version(1, 2, 3, buildMetadataIdentifiers: ["123alpha"]))
        
        XCTAssertFalse(Version(2, 2, 3, prereleaseIdentifiers: [""]) < Version(1, 2, 3, buildMetadataIdentifiers: [""]))
        XCTAssertFalse(Version(1, 3, 3, prereleaseIdentifiers: ["alpha"]) < Version(1, 2, 3, buildMetadataIdentifiers: ["beta"]))
        XCTAssertFalse(Version(1, 2, 4, prereleaseIdentifiers: ["223"]) < Version(1, 2, 3, buildMetadataIdentifiers: ["123alpha"]))

        // MARK: version core + build metadata vs. version core + build metadata

        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: [""]), Version(1, 2, 3, buildMetadataIdentifiers: [""]))

        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["beta"]), Version(1, 2, 3, buildMetadataIdentifiers: ["beta"]))
        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["alpha"]), Version(1, 2, 3, buildMetadataIdentifiers: ["beta"]))
        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["alpha1"]), Version(1, 2, 3, buildMetadataIdentifiers: ["alpha2"]))
        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["alpha"]), Version(1, 2, 3, buildMetadataIdentifiers: ["alpha-"]))
        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["beta", "alpha"]), Version(1, 2, 3, buildMetadataIdentifiers: ["beta", "beta"]))
        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["alpha", "beta"]), Version(1, 2, 3, buildMetadataIdentifiers: ["beta", "alpha"]))

        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["1"]), Version(1, 2, 3, buildMetadataIdentifiers: ["1"]))
        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["1"]), Version(1, 2, 3, buildMetadataIdentifiers: ["2"]))
        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["1", "1"]), Version(1, 2, 3, buildMetadataIdentifiers: ["1", "2"]))
        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["1", "2"]), Version(1, 2, 3, buildMetadataIdentifiers: ["2", "1"]))

        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["123"]), Version(1, 2, 3, buildMetadataIdentifiers: ["123alpha"]))
        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["223"]), Version(1, 2, 3, buildMetadataIdentifiers: ["123alpha"]))

        // MARK: version core vs. version core + pre-release + build metadata

        XCTAssertGreaterThan(Version(1, 2, 3), Version(1, 2, 3, prereleaseIdentifiers: [""], buildMetadataIdentifiers: [""]))
        XCTAssertGreaterThan(Version(1, 2, 3), Version(1, 2, 3, prereleaseIdentifiers: [""], buildMetadataIdentifiers: ["123alpha"]))
        XCTAssertGreaterThan(Version(1, 2, 3), Version(1, 2, 3, prereleaseIdentifiers: ["alpha"], buildMetadataIdentifiers: ["alpha"]))
        XCTAssertGreaterThan(Version(1, 2, 3), Version(1, 2, 3, prereleaseIdentifiers: ["beta"], buildMetadataIdentifiers: ["123"]))
        XCTAssertLessThan(Version(1, 2, 2), Version(1, 2, 3, prereleaseIdentifiers: ["beta"], buildMetadataIdentifiers: ["alpha", "beta"]))
        XCTAssertLessThan(Version(1, 2, 2), Version(1, 2, 3, prereleaseIdentifiers: ["beta"], buildMetadataIdentifiers: ["alpha-"]))
        
        XCTAssertFalse(Version(1, 2, 3) < Version(1, 2, 3, prereleaseIdentifiers: [""], buildMetadataIdentifiers: [""]))
        XCTAssertFalse(Version(1, 2, 3) < Version(1, 2, 3, prereleaseIdentifiers: [""], buildMetadataIdentifiers: ["123alpha"]))
        XCTAssertFalse(Version(1, 2, 3) < Version(1, 2, 3, prereleaseIdentifiers: ["alpha"], buildMetadataIdentifiers: ["alpha"]))
        XCTAssertFalse(Version(1, 2, 3) < Version(1, 2, 3, prereleaseIdentifiers: ["beta"], buildMetadataIdentifiers: ["123"]))

        // MARK: version core + pre-release vs. version core + pre-release + build metadata

        XCTAssertEqual(
            Version(1, 2, 3, prereleaseIdentifiers: [""]),
            Version(1, 2, 3, prereleaseIdentifiers: [""], buildMetadataIdentifiers: [""])
        )

        XCTAssertEqual(
            Version(1, 2, 3, prereleaseIdentifiers: ["beta"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["beta"], buildMetadataIdentifiers: [""])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["alpha"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["beta"], buildMetadataIdentifiers: ["123alpha"])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["alpha1"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["alpha2"], buildMetadataIdentifiers: ["alpha"])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["alpha"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["alpha-"], buildMetadataIdentifiers: ["alpha", "beta"])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["beta", "alpha"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["beta", "beta"], buildMetadataIdentifiers: ["123"])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["alpha", "beta"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["beta", "alpha"], buildMetadataIdentifiers: ["alpha-"])
        )

        XCTAssertEqual(
            Version(1, 2, 3, prereleaseIdentifiers: ["1"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["1"], buildMetadataIdentifiers: [""])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["1"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["2"], buildMetadataIdentifiers: ["123alpha"])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["1", "1"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["1", "2"], buildMetadataIdentifiers: ["123"])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["1", "2"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["2", "1"], buildMetadataIdentifiers: ["alpha", "beta"])
        )

        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["123"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["123alpha"], buildMetadataIdentifiers: ["-alpha"])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["223"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["123alpha"], buildMetadataIdentifiers: ["123"])
        )

        // MARK: version core + pre-release + build metadata vs. version core + pre-release + build metadata

        XCTAssertEqual(
            Version(1, 2, 3, prereleaseIdentifiers: [""], buildMetadataIdentifiers: [""]),
            Version(1, 2, 3, prereleaseIdentifiers: [""], buildMetadataIdentifiers: [""])
        )

        XCTAssertEqual(
            Version(1, 2, 3, prereleaseIdentifiers: ["beta"], buildMetadataIdentifiers: ["123"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["beta"], buildMetadataIdentifiers: [""])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["alpha"], buildMetadataIdentifiers: ["-alpha"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["beta"], buildMetadataIdentifiers: ["123alpha"])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["alpha1"], buildMetadataIdentifiers: ["alpha", "beta"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["alpha2"], buildMetadataIdentifiers: ["alpha"])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["alpha"], buildMetadataIdentifiers: ["123"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["alpha-"], buildMetadataIdentifiers: ["alpha", "beta"])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["beta", "alpha"], buildMetadataIdentifiers: ["123alpha"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["beta", "beta"], buildMetadataIdentifiers: ["123"])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["alpha", "beta"], buildMetadataIdentifiers: [""]),
            Version(1, 2, 3, prereleaseIdentifiers: ["beta", "alpha"], buildMetadataIdentifiers: ["alpha-"])
        )

        XCTAssertEqual(
            Version(1, 2, 3, prereleaseIdentifiers: ["1"], buildMetadataIdentifiers: ["alpha-"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["1"], buildMetadataIdentifiers: [""])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["1"], buildMetadataIdentifiers: ["123"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["2"], buildMetadataIdentifiers: ["123alpha"])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["1", "1"], buildMetadataIdentifiers: ["alpha", "beta"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["1", "2"], buildMetadataIdentifiers: ["123"])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["1", "2"], buildMetadataIdentifiers: ["alpha"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["2", "1"], buildMetadataIdentifiers: ["alpha", "beta"])
        )

        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["123"], buildMetadataIdentifiers: ["123alpha"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["123alpha"], buildMetadataIdentifiers: ["-alpha"])
        )
        XCTAssertLessThan(
            Version(1, 2, 3, prereleaseIdentifiers: ["223"], buildMetadataIdentifiers: ["123alpha"]),
            Version(1, 2, 3, prereleaseIdentifiers: ["123alpha"], buildMetadataIdentifiers: ["123"])
        )

    }

    func testAdditionalVersionComparison() {
        do {
            let v1 = Version(1,2,3)
            let v2 = Version(2,1,2)
            XCTAssertLessThan(v1, v2)
            XCTAssertLessThanOrEqual(v1, v2)
            XCTAssertGreaterThan(v2, v1)
            XCTAssertGreaterThanOrEqual(v2, v1)
            XCTAssertNotEqual(v1, v2)
            XCTAssertFalse(v2 < v1)

            XCTAssertLessThanOrEqual(v1, v1)
            XCTAssertGreaterThanOrEqual(v1, v1)
            XCTAssertFalse(v1 < v1)
            XCTAssertLessThanOrEqual(v2, v2)
            XCTAssertGreaterThanOrEqual(v2, v2)
            XCTAssertFalse(v2 < v2)
        }

        do {
            let v3 = Version(2,1,3)
            let v4 = Version(2,2,2)
            XCTAssertLessThan(v3, v4)
            XCTAssertLessThanOrEqual(v3, v4)
            XCTAssertGreaterThan(v4, v3)
            XCTAssertGreaterThanOrEqual(v4, v3)
            XCTAssertNotEqual(v3, v4)
            XCTAssertFalse(v4 < v3)

            XCTAssertLessThanOrEqual(v3, v3)
            XCTAssertGreaterThanOrEqual(v3, v3)
            XCTAssertFalse(v3 < v3)
            XCTAssertLessThanOrEqual(v4, v4)
            XCTAssertGreaterThanOrEqual(v4, v4)
            XCTAssertFalse(v4 < v4)
        }

        do {
            let v5 = Version(2,1,2)
            let v6 = Version(2,1,3)
            XCTAssertLessThan(v5, v6)
            XCTAssertLessThanOrEqual(v5, v6)
            XCTAssertGreaterThan(v6, v5)
            XCTAssertGreaterThanOrEqual(v6, v5)
            XCTAssertNotEqual(v5, v6)
            XCTAssertFalse(v6 < v5)

            XCTAssertLessThanOrEqual(v5, v5)
            XCTAssertGreaterThanOrEqual(v5, v5)
            XCTAssertFalse(v5 < v5)
            XCTAssertLessThanOrEqual(v6, v6)
            XCTAssertGreaterThanOrEqual(v6, v6)
            XCTAssertFalse(v6 < v6)
        }

        do {
            let v7 = Version(0,9,21)
            let v8 = Version(2,0,0)
            XCTAssert(v7 < v8)
            XCTAssertLessThan(v7, v8)
            XCTAssertLessThanOrEqual(v7, v8)
            XCTAssertGreaterThan(v8, v7)
            XCTAssertGreaterThanOrEqual(v8, v7)
            XCTAssertNotEqual(v7, v8)
            XCTAssertFalse(v8 < v7)

            XCTAssertLessThanOrEqual(v7, v7)
            XCTAssertGreaterThanOrEqual(v7, v7)
            XCTAssertFalse(v7 < v7)
            XCTAssertLessThanOrEqual(v8, v8)
            XCTAssertGreaterThanOrEqual(v8, v8)
            XCTAssertFalse(v8 < v8)
        }

        do {
            // Prerelease precedence tests taken directly from http://semver.org
            var tests: [Version] = [
                "1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta",
                "1.0.0-beta.2", "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0"
            ]

            var v1 = tests.removeFirst()
            for v2 in tests {
                XCTAssertLessThan(v1, v2)
                XCTAssertLessThanOrEqual(v1, v2)
                XCTAssertGreaterThan(v2, v1)
                XCTAssertGreaterThanOrEqual(v2, v1)
                XCTAssertNotEqual(v1, v2)
                XCTAssertFalse(v2 < v1)

                XCTAssertLessThanOrEqual(v1, v1)
                XCTAssertGreaterThanOrEqual(v1, v1)
                XCTAssertFalse(v1 < v1)
                XCTAssertLessThanOrEqual(v2, v2)
                XCTAssertGreaterThanOrEqual(v2, v2)
                XCTAssertFalse(v2 < v2)

                v1 = v2
            }
        }

        XCTAssertLessThan(Version(0,0,0), Version(0,0,1))
        XCTAssertLessThan(Version(0,0,1), Version(0,1,0))
        XCTAssertLessThan(Version(0,1,0), Version(0,10,0))
        XCTAssertLessThan(Version(0,10,0), Version(1,0,0))
        XCTAssertLessThan(Version(1,0,0), Version(2,0,0))
        XCTAssert(!(Version(1,0,0) < Version(1,0,0)))
        XCTAssert(!(Version(2,0,0) < Version(1,0,0)))
    }

    func testAdditionalVersionEquality() {
        let versions: [Version] = ["1.2.3", "0.0.0",
            "0.0.0-alpha+yol", "0.0.0-alpha.1+pol",
            "0.1.2", "10.7.3",
        ]
        // Test that each version is equal to itself and not equal to others.
        for (idx, version) in versions.enumerated() {
            for (ridx, rversion) in versions.enumerated() {
                if idx == ridx {
                    XCTAssertEqual(version, rversion)
                    // Construct the object again with different initializer.
                    XCTAssertEqual(version,
                        Version(rversion.major, rversion.minor, rversion.patch,
                            prereleaseIdentifiers: rversion.prereleaseIdentifiers,
                            buildMetadataIdentifiers: rversion.buildMetadataIdentifiers))
                } else {
                    XCTAssertNotEqual(version, rversion)
                }
            }
        }
    }

    func testHashable() {
        let versions: [Version] = ["1.2.3", "1.2.3", "1.2.3",
            "1.0.0-alpha", "1.0.0-alpha",
            "1.0.0", "1.0.0"
        ]
        XCTAssertEqual(Set(versions), Set(["1.0.0-alpha", "1.2.3", "1.0.0"]))

        XCTAssertEqual(Set([Version(1,2,3)]), Set([Version(1,2,3)]))
        XCTAssertNotEqual(Set([Version(1,2,3)]), Set([Version(1,2,3, prereleaseIdentifiers: ["alpha"])]))
        XCTAssertEqual(Set([Version(1,2,3)]), Set([Version(1,2,3, buildMetadataIdentifiers: ["1011"])]))
    }

    func testCustomConversionFromVersionToString() {

        // MARK: Version.description

        XCTAssertEqual(Version(0, 0, 0).description, "0.0.0" as String)
        XCTAssertEqual(Version(1, 2, 3).description, "1.2.3" as String)
        XCTAssertEqual(Version(1, 2, 3, prereleaseIdentifiers: [""]).description, "1.2.3-" as String)
        XCTAssertEqual(Version(1, 2, 3, prereleaseIdentifiers: ["", ""]).description, "1.2.3-." as String)
        XCTAssertEqual(Version(1, 2, 3, prereleaseIdentifiers: ["beta1"]).description, "1.2.3-beta1" as String)
        XCTAssertEqual(Version(1, 2, 3, prereleaseIdentifiers: ["beta", "1"]).description, "1.2.3-beta.1" as String)
        XCTAssertEqual(Version(1, 2, 3, prereleaseIdentifiers: ["beta", "", "1"]).description, "1.2.3-beta..1" as String)
        XCTAssertEqual(Version(1, 2, 3, prereleaseIdentifiers: ["be-ta", "", "1"]).description, "1.2.3-be-ta..1" as String)
        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: [""]).description, "1.2.3+" as String)
        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["", ""]).description, "1.2.3+." as String)
        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["beta1"]).description, "1.2.3+beta1" as String)
        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["beta", "1"]).description, "1.2.3+beta.1" as String)
        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["beta", "", "1"]).description, "1.2.3+beta..1" as String)
        XCTAssertEqual(Version(1, 2, 3, buildMetadataIdentifiers: ["be-ta", "", "1"]).description, "1.2.3+be-ta..1" as String)
        XCTAssertEqual(Version(1, 2, 3, prereleaseIdentifiers: [""], buildMetadataIdentifiers: [""]).description, "1.2.3-+" as String)
        XCTAssertEqual(Version(1, 2, 3, prereleaseIdentifiers: ["", ""], buildMetadataIdentifiers: ["", "-", ""]).description, "1.2.3-.+.-." as String)
        XCTAssertEqual(Version(1, 2, 3, prereleaseIdentifiers: ["beta1"], buildMetadataIdentifiers: ["alpha1"]).description, "1.2.3-beta1+alpha1" as String)
        XCTAssertEqual(Version(1, 2, 3, prereleaseIdentifiers: ["beta", "1"], buildMetadataIdentifiers: ["alpha", "1"]).description, "1.2.3-beta.1+alpha.1" as String)
        XCTAssertEqual(Version(1, 2, 3, prereleaseIdentifiers: ["beta", "", "1"], buildMetadataIdentifiers: ["alpha", "", "1"]).description, "1.2.3-beta..1+alpha..1" as String)
        XCTAssertEqual(Version(1, 2, 3, prereleaseIdentifiers: ["be-ta", "", "1"], buildMetadataIdentifiers: ["al-pha", "", "1"]).description, "1.2.3-be-ta..1+al-pha..1" as String)

        // MARK: String interpolation

        XCTAssertEqual("\(Version(0, 0, 0))", "0.0.0" as String)
        XCTAssertEqual("\(Version(1, 2, 3))", "1.2.3" as String)
        XCTAssertEqual("\(Version(1, 2, 3, prereleaseIdentifiers: [""]))", "1.2.3-" as String)
        XCTAssertEqual("\(Version(1, 2, 3, prereleaseIdentifiers: ["", ""]))", "1.2.3-." as String)
        XCTAssertEqual("\(Version(1, 2, 3, prereleaseIdentifiers: ["beta1"]))", "1.2.3-beta1" as String)
        XCTAssertEqual("\(Version(1, 2, 3, prereleaseIdentifiers: ["beta", "1"]))", "1.2.3-beta.1" as String)
        XCTAssertEqual("\(Version(1, 2, 3, prereleaseIdentifiers: ["beta", "", "1"]))", "1.2.3-beta..1" as String)
        XCTAssertEqual("\(Version(1, 2, 3, prereleaseIdentifiers: ["be-ta", "", "1"]))", "1.2.3-be-ta..1" as String)
        XCTAssertEqual("\(Version(1, 2, 3, buildMetadataIdentifiers: [""]))", "1.2.3+" as String)
        XCTAssertEqual("\(Version(1, 2, 3, buildMetadataIdentifiers: ["", ""]))", "1.2.3+." as String)
        XCTAssertEqual("\(Version(1, 2, 3, buildMetadataIdentifiers: ["beta1"]))", "1.2.3+beta1" as String)
        XCTAssertEqual("\(Version(1, 2, 3, buildMetadataIdentifiers: ["beta", "1"]))", "1.2.3+beta.1" as String)
        XCTAssertEqual("\(Version(1, 2, 3, buildMetadataIdentifiers: ["beta", "", "1"]))", "1.2.3+beta..1" as String)
        XCTAssertEqual("\(Version(1, 2, 3, buildMetadataIdentifiers: ["be-ta", "", "1"]))", "1.2.3+be-ta..1" as String)
        XCTAssertEqual("\(Version(1, 2, 3, prereleaseIdentifiers: [""], buildMetadataIdentifiers: [""]))", "1.2.3-+" as String)
        XCTAssertEqual("\(Version(1, 2, 3, prereleaseIdentifiers: ["", ""], buildMetadataIdentifiers: ["", "-", ""]))", "1.2.3-.+.-." as String)
        XCTAssertEqual("\(Version(1, 2, 3, prereleaseIdentifiers: ["beta1"], buildMetadataIdentifiers: ["alpha1"]))", "1.2.3-beta1+alpha1" as String)
        XCTAssertEqual("\(Version(1, 2, 3, prereleaseIdentifiers: ["beta", "1"], buildMetadataIdentifiers: ["alpha", "1"]))", "1.2.3-beta.1+alpha.1" as String)
        XCTAssertEqual("\(Version(1, 2, 3, prereleaseIdentifiers: ["beta", "", "1"], buildMetadataIdentifiers: ["alpha", "", "1"]))", "1.2.3-beta..1+alpha..1" as String)
        XCTAssertEqual("\(Version(1, 2, 3, prereleaseIdentifiers: ["be-ta", "", "1"], buildMetadataIdentifiers: ["al-pha", "", "1"]))", "1.2.3-be-ta..1+al-pha..1" as String)

    }

    func testAdditionalCustomConversionFromVersionToString() {
        let v: Version = "123.234.345-alpha.beta+sha1.1011"
        XCTAssertEqual(v.description, "123.234.345-alpha.beta+sha1.1011")
        XCTAssertEqual(v.major, 123)
        XCTAssertEqual(v.minor, 234)
        XCTAssertEqual(v.patch, 345)
        XCTAssertEqual(v.prereleaseIdentifiers, ["alpha", "beta"])
        XCTAssertEqual(v.buildMetadataIdentifiers, ["sha1", "1011"])
    }

    func testLosslessConversionFromStringToVersion() {

        // We use type coercion `as String` in `Version(_:)` because there is a pair of overloaded initializers: `init(_ version: Version)` and `init?(_ versionString: String)`, and we want to test the latter in this function.

        // MARK: Well-formed version core

        XCTAssertNotNil(Version("0.0.0" as String))
        XCTAssertEqual(Version("0.0.0" as String), Version(0, 0, 0))

        XCTAssertNotNil(Version("1.1.2" as String))
        XCTAssertEqual(Version("1.1.2" as String), Version(1, 1, 2))

        // MARK: Malformed version core

        XCTAssertNil(Version("3" as String))
        XCTAssertNil(Version("3 5" as String))
        XCTAssertNil(Version("5.8" as String))
        XCTAssertNil(Version("-5.8.13" as String))
        XCTAssertNil(Version("8.-13.21" as String))
        XCTAssertNil(Version("13.21.-34" as String))
        XCTAssertNil(Version("-0.0.0" as String))
        XCTAssertNil(Version("0.-0.0" as String))
        XCTAssertNil(Version("0.0.-0" as String))
        XCTAssertNil(Version("21.34.55.89" as String))
        XCTAssertNil(Version("6 x 9 = 42" as String))
        XCTAssertNil(Version("forty two" as String))

        // MARK: Well-formed version core, well-formed pre-release identifiers

        XCTAssertNotNil(Version("0.0.0-pre-alpha" as String))
        XCTAssertEqual(Version("0.0.0-pre-alpha" as String), Version(0, 0, 0, prereleaseIdentifiers: ["pre-alpha"]))

        XCTAssertNotNil(Version("55.89.144-beta.1" as String))
        XCTAssertEqual(Version("55.89.144-beta.1" as String), Version(55, 89, 144, prereleaseIdentifiers: ["beta", "1"]))

        XCTAssertNotNil(Version("89.144.233-a.whole..lot.of.pre-release.identifiers" as String))
        XCTAssertEqual(Version("89.144.233-a.whole..lot.of.pre-release.identifiers" as String), Version(89, 144, 233, prereleaseIdentifiers: ["a", "whole", "", "lot", "of", "pre-release", "identifiers"]))

        XCTAssertNotNil(Version("144.233.377-" as String))
        XCTAssertEqual(Version("144.233.377-" as String), Version(144, 233, 377, prereleaseIdentifiers: [""]))

        // MARK: Well-formed version core, malformed pre-release identifiers

        XCTAssertNil(Version("233.377.610-hello world" as String))

        // MARK: Malformed version core, well-formed pre-release identifiers

        XCTAssertNil(Version("987-Hello.world--------" as String))
        XCTAssertNil(Version("987.1597-half-life.3" as String))
        XCTAssertNil(Version("1597.2584.4181.6765-a.whole.lot.of.pre-release.identifiers" as String))
        XCTAssertNil(Version("6 x 9 = 42-" as String))
        XCTAssertNil(Version("forty-two" as String))

        // MARK: Well-formed version core, well-formed build metadata identifiers

        XCTAssertNotNil(Version("0.0.0+some-metadata" as String))
        XCTAssertEqual(Version("0.0.0+some-metadata" as String), Version(0, 0, 0, buildMetadataIdentifiers: ["some-metadata"]))

        XCTAssertNotNil(Version("4181.6765.10946+more.meta..more.data" as String))
        XCTAssertEqual(Version("4181.6765.10946+more.meta..more.data" as String), Version(4181, 6765, 10946, buildMetadataIdentifiers: ["more", "meta", "", "more", "data"]))

        XCTAssertNotNil(Version("6765.10946.17711+-a-very--long---build-----metadata--------identifier-------------with---------------------many----------------------------------hyphens-------------------------------------------------------" as String))
        XCTAssertEqual(Version("6765.10946.17711+-a-very--long---build-----metadata--------identifier-------------with---------------------many----------------------------------hyphens-------------------------------------------------------" as String), Version(6765, 10946, 17711, buildMetadataIdentifiers: ["-a-very--long---build-----metadata--------identifier-------------with---------------------many----------------------------------hyphens-------------------------------------------------------"]))

        XCTAssertNotNil(Version("10946.17711.28657+" as String))
        XCTAssertEqual(Version("10946.17711.28657+" as String), Version(10946, 17711, 28657, buildMetadataIdentifiers: [""]))

        // MARK: Well-formed version core, malformed build metadata identifiers

        XCTAssertNil(Version("17711.28657.46368+hello world" as String))
        XCTAssertNil(Version("28657.46368.75025+hello+world" as String))

        // MARK: Malformed version core, well-formed build metadata identifiers

        XCTAssertNil(Version("121393+Hello.world--------" as String))
        XCTAssertNil(Version("121393.196418+half-life.3" as String))
        XCTAssertNil(Version("196418.317811.514229.832040+a.whole.lot.of.build.metadata.identifiers" as String))
        XCTAssertNil(Version("6 x 9 = 42+" as String))
        XCTAssertNil(Version("forty two+a-very-long-build-metadata-identifier-with-many-hyphens" as String))

        // MARK: Well-formed version core, well-formed pre-release identifiers, well-formed build metadata identifiers

        XCTAssertNotNil(Version("0.0.0-beta.-42+42-42.42" as String))
        XCTAssertEqual(Version("0.0.0-beta.-42+42-42.42" as String), Version(0, 0, 0, prereleaseIdentifiers: ["beta", "-42"], buildMetadataIdentifiers: ["42-42", "42"]))

        // MARK: Well-formed version core, well-formed pre-release identifiers, malformed build metadata identifiers

        XCTAssertNil(Version("514229.832040.1346269-beta1+  " as String))

        // MARK: Well-formed version core, malformed pre-release identifiers, well-formed build metadata identifiers

        XCTAssertNil(Version("832040.1346269.2178309-beta 1+-" as String))

        // MARK: Well-formed version core, malformed pre-release identifiers, malformed build metadata identifiers

        XCTAssertNil(Version("1346269.2178309.3524578-beta 1++" as String))

        // MARK: malformed version core, well-formed pre-release identifiers, well-formed build metadata identifiers

        XCTAssertNil(Version(" 832040.1346269.3524578-beta1+abc" as String))

        // MARK: malformed version core, well-formed pre-release identifiers, malformed build metadata identifiers

        XCTAssertNil(Version("l346269.3524578.5702887-beta1+😀" as String))

        // MARK: malformed version core, malformed pre-release identifiers, well-formed build metadata identifiers

        XCTAssertNil(Version("352A578.5702887.9227465-beta!@#$%^&*1+asdfghjkl123456789" as String))

        // MARK: malformed version core, malformed pre-release identifiers, malformed build metadata identifiers

        XCTAssertNil(Version("5702887.9227465-bètá1+±" as String))

    }

    func testExpressingVersionByStringLiteral() {

        // MARK: Well-formed version core

        XCTAssertEqual("0.0.0" as Version, Version(0, 0, 0))
        XCTAssertEqual("1.1.2" as Version, Version(1, 1, 2))

        // MARK: Well-formed version core, well-formed pre-release identifiers

        XCTAssertEqual("0.0.0-pre-alpha" as Version, Version(0, 0, 0, prereleaseIdentifiers: ["pre-alpha"]))
        XCTAssertEqual("55.89.144-beta.1" as Version, Version(55, 89, 144, prereleaseIdentifiers: ["beta", "1"]))
        XCTAssertEqual("89.144.233-a.whole..lot.of.pre-release.identifiers" as Version, Version(89, 144, 233, prereleaseIdentifiers: ["a", "whole", "", "lot", "of", "pre-release", "identifiers"]))
        XCTAssertEqual("144.233.377-" as Version, Version(144, 233, 377, prereleaseIdentifiers: [""]))

        // MARK: Well-formed version core, well-formed build metadata identifiers

        XCTAssertEqual("0.0.0+some-metadata" as Version, Version(0, 0, 0, buildMetadataIdentifiers: ["some-metadata"]))
        XCTAssertEqual("4181.6765.10946+more.meta..more.data" as Version, Version(4181, 6765, 10946, buildMetadataIdentifiers: ["more", "meta", "", "more", "data"]))
        XCTAssertEqual("6765.10946.17711+-a-very--long---build-----metadata--------identifier-------------with---------------------many----------------------------------hyphens-------------------------------------------------------" as Version, Version(6765, 10946, 17711, buildMetadataIdentifiers: ["-a-very--long---build-----metadata--------identifier-------------with---------------------many----------------------------------hyphens-------------------------------------------------------"]))
        XCTAssertEqual("10946.17711.28657+" as Version, Version(10946, 17711, 28657, buildMetadataIdentifiers: [""]))

    }

    func testAdditionalInitializationFromString() {
        let badStrings = [
            "", "1", "1.2", "1.2.3.4", "1.2.3.4.5",
            "a", "1.a", "a.2", "a.2.3", "1.a.3", "1.2.a",
            "-1.2.3", "1.-2.3", "1.2.-3", ".1.2.3", "v.1.2.3", "1.2..3", "v1.2.3",
        ]
        for str in badStrings {
            XCTAssertNil(Version(str))
        }

        XCTAssertEqual(Version(1,2,3), Version("1.2.3"))
        XCTAssertEqual(Version(1,2,3), Version("01.002.0003"))
        XCTAssertEqual(Version(0,9,21), Version("0.9.21"))
        XCTAssertEqual(Version(0,9,21, prereleaseIdentifiers: ["alpha", "beta"], buildMetadataIdentifiers: ["1011"]),
            Version("0.9.21-alpha.beta+1011"))
        XCTAssertEqual(Version(0,9,21, prereleaseIdentifiers: [], buildMetadataIdentifiers: ["1011"]), Version("0.9.21+1011"))
    }

    func testRange() {
        switch Version(1,2,4) {
        case Version(1,2,3)..<Version(2,3,4):
            break
        default:
            XCTFail()
        }

        switch Version(1,2,4) {
        case Version(1,2,3)..<Version(2,3,4):
            break
        case Version(1,2,5)..<Version(1,2,6):
            XCTFail()
        default:
            XCTFail()
        }

        switch Version(1,2,4) {
        case Version(1,2,3)..<Version(1,2,4):
            XCTFail()
        case Version(1,2,5)..<Version(1,2,6):
            XCTFail()
        default:
            break
        }

        switch Version(1,2,4) {
        case Version(1,2,5)..<Version(2,0,0):
            XCTFail()
        case Version(2,0,0)..<Version(2,2,6):
            XCTFail()
        case Version(0,0,1)..<Version(0,9,6):
            XCTFail()
        default:
            break
        }
    }

    func testContains() {
        do {
            let range: Range<Version> = "1.0.0"..<"2.0.0"

            XCTAssertTrue(range.contains(version: "1.0.0"))
            XCTAssertTrue(range.contains(version: "1.5.0"))
            XCTAssertTrue(range.contains(version: "1.9.99999"))
            XCTAssertTrue(range.contains(version: "1.9.99999+1232"))

            XCTAssertFalse(range.contains(version: "1.0.0-alpha"))
            XCTAssertFalse(range.contains(version: "1.5.0-alpha"))
            XCTAssertFalse(range.contains(version: "2.0.0-alpha"))
            XCTAssertFalse(range.contains(version: "2.0.0"))
        }

        do {
            let range: Range<Version> = "1.0.0"..<"2.0.0-beta"

            XCTAssertTrue(range.contains(version: "1.0.0"))
            XCTAssertTrue(range.contains(version: "1.5.0"))
            XCTAssertTrue(range.contains(version: "1.9.99999"))
            XCTAssertTrue(range.contains(version: "1.0.1-alpha"))
            XCTAssertTrue(range.contains(version: "2.0.0-alpha"))

            XCTAssertFalse(range.contains(version: "1.0.0-alpha"))
            XCTAssertFalse(range.contains(version: "2.0.0"))
            XCTAssertFalse(range.contains(version: "2.0.0-beta"))
            XCTAssertFalse(range.contains(version: "2.0.0-clpha"))
        }

        do {
            let range: Range<Version> = "1.0.0-alpha"..<"2.0.0"
            XCTAssertTrue(range.contains(version: "1.0.0"))
            XCTAssertTrue(range.contains(version: "1.5.0"))
            XCTAssertTrue(range.contains(version: "1.9.99999"))
            XCTAssertTrue(range.contains(version: "1.0.0-alpha"))
            XCTAssertTrue(range.contains(version: "1.0.0-beta"))
            XCTAssertTrue(range.contains(version: "1.0.1-alpha"))

            XCTAssertFalse(range.contains(version: "2.0.0-alpha"))
            XCTAssertFalse(range.contains(version: "2.0.0-beta"))
            XCTAssertFalse(range.contains(version: "2.0.0-clpha"))
            XCTAssertFalse(range.contains(version: "2.0.0"))
        }

        do {
            let range: Range<Version> = "1.0.0"..<"1.1.0"
            XCTAssertTrue(range.contains(version: "1.0.0"))
            XCTAssertTrue(range.contains(version: "1.0.9"))

            XCTAssertFalse(range.contains(version: "1.1.0"))
            XCTAssertFalse(range.contains(version: "1.2.0"))
            XCTAssertFalse(range.contains(version: "1.5.0"))
            XCTAssertFalse(range.contains(version: "2.0.0"))
            XCTAssertFalse(range.contains(version: "1.0.0-beta"))
            XCTAssertFalse(range.contains(version: "1.0.10-clpha"))
            XCTAssertFalse(range.contains(version: "1.1.0-alpha"))
        }

        do {
            let range: Range<Version> = "1.0.0"..<"1.1.0-alpha"
            XCTAssertTrue(range.contains(version: "1.0.0"))
            XCTAssertTrue(range.contains(version: "1.0.9"))
            XCTAssertTrue(range.contains(version: "1.0.1-beta"))
            XCTAssertTrue(range.contains(version: "1.0.10-clpha"))

            XCTAssertFalse(range.contains(version: "1.1.0"))
            XCTAssertFalse(range.contains(version: "1.2.0"))
            XCTAssertFalse(range.contains(version: "1.5.0"))
            XCTAssertFalse(range.contains(version: "2.0.0"))
            XCTAssertFalse(range.contains(version: "1.0.0-alpha"))
            XCTAssertFalse(range.contains(version: "1.1.0-alpha"))
            XCTAssertFalse(range.contains(version: "1.1.0-beta"))
        }
    }

}
