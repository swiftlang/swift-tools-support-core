# This source file is part of the Swift.org open source project
#
# Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

add_library(TSCBasic
  Await.swift
  ByteString.swift
  CStringArray.swift
  CacheableSequence.swift
  Closable.swift
  CodableResult.swift
  CollectionAlgorithms.swift
  CollectionExtensions.swift
  Condition.swift
  DeltaAlgorithm.swift
  DiagnosticsEngine.swift
  DictionaryExtensions.swift
  DictionaryLiteralExtensions.swift
  EditDistance.swift
  FileInfo.swift
  FileSystem.swift
  GraphAlgorithms.swift
  HashAlgorithms.swift
  JSON.swift
  JSONMapper.swift
  KeyedPair.swift
  LazyCache.swift
  Lock.swift
  OSLog.swift
  ObjectIdentifierProtocol.swift
  OrderedDictionary.swift
  OrderedSet.swift
  WritableByteStream.swift
  Path.swift
  PathShims.swift
  Process/Process.swift
  Process/ProcessEnv.swift
  Process/ProcessSet.swift
  RegEx.swift
  Result.swift
  SortedArray.swift
  StringConversions.swift
  SynchronizedQueue.swift
  TemporaryFile.swift
  TerminalController.swift
  Thread.swift
  Tuple.swift
  misc.swift)

target_compile_options(TSCBasic PUBLIC
  # Ignore secure function warnings on Windows.
  "$<$<PLATFORM_ID:Windows>:SHELL:-Xcc -D_CRT_SECURE_NO_WARNINGS>")
target_link_libraries(TSCBasic PRIVATE
  TSCclibc
  TSCLibc)
if(NOT CMAKE_SYSTEM_NAME STREQUAL Darwin)
  if(Foundation_FOUND)
    target_link_libraries(TSCBasic PUBLIC
      Foundation)
  endif()
endif()
target_link_libraries(TSCBasic PRIVATE
  $<$<PLATFORM_ID:Windows>:Pathcch>)
# NOTE(compnerd) workaround for CMake not setting up include flags yet
set_target_properties(TSCBasic PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_Swift_MODULE_DIRECTORY})

install(TARGETS TSCBasic
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin)

set_property(GLOBAL APPEND PROPERTY TSC_EXPORTS TSCBasic)
