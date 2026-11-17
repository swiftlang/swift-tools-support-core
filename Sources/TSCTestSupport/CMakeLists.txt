# This source file is part of the Swift.org open source project
#
# Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

add_library(TSCTestSupport
  AssertMatch.swift
  DiagnosticsEngine.swift
  FileSystemExtensions.swift
  JSONExtensions.swift
  misc.swift
  Product.swift
  PseudoTerminal.swift
  XCTAssertHelpers.swift
  XCTestCasePerf.swift)
target_link_libraries(TSCTestSupport PUBLIC
  TSCBasic
  TSCLibc
  TSCUtility)
if(NOT APPLE)
  if(Foundation_FOUND)
    target_link_libraries(TSCTestSupport PRIVATE
      Foundation)
  endif()
  if(XCTest_FOUND)
    target_link_libraries(TSCTestSupport PRIVATE
      XCTest)
  endif()
endif()
