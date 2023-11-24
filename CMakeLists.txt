if(POLICY CMP0028)
  cmake_policy(SET CMP0028 NEW)
endif()

cmake_minimum_required(VERSION 3.19)

project(SwiftTSC LANGUAGES C Swift)

set(CMAKE_Swift_LANGUAGE_VERSION 5)
set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set(CMAKE_DISABLE_IN_SOURCE_BUILD YES)

option(BUILD_SHARED_LIBS "Build shared libraries by default" YES)

# Toolchain bundled libraries
find_package(dispatch QUIET)
find_package(Foundation QUIET)

# System Packages
find_package(Threads QUIET)

# Package Dependencies
find_package(SwiftSystem CONFIG)
if(NOT SwiftSystem_FOUND)
  include(FetchContent)
  message("-- Vendoring SwiftSystem")
  FetchContent_Declare(SwiftSystem
    GIT_REPOSITORY https://github.com/apple/swift-system
    GIT_TAG 1.1.1)
  FetchContent_MakeAvailable(SwiftSystem)
endif()

add_subdirectory(Sources)
add_subdirectory(cmake/modules)
