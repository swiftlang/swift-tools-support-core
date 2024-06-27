swift-tools-support-core
=========================

Contains common infrastructural code for both [SwiftPM](https://github.com/swiftlang/swift-package-manager)
and [llbuild](https://github.com/apple/swift-llbuild).

## ⚠️ This package is deprecated

As this package with time has become a collection of unrelated utilities, that made it much harder to version.
Primary users of TSC such as SwiftPM and Swift Driver came up with specialized alternatives to APIs provided
in TSC. Moving forward, we don't recommend adding TSC as a dependency to your project. More and more types
and functions here will be deprecated, with minimal modifications to ease the migration off TSC.

License
-------

See http://swift.org/LICENSE.txt for license information.
