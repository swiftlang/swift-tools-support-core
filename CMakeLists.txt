cmake_minimum_required(VERSION 3.19)

project(SwiftTSC LANGUAGES C Swift)

set(CMAKE_Swift_LANGUAGE_VERSION 5)
set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set(CMAKE_DISABLE_IN_SOURCE_BUILD YES)

option(BUILD_SHARED_LIBS "Build shared libraries by default" YES)

find_package(dispatch QUIET)
find_package(Foundation QUIET)
find_package(Threads QUIET)
find_package(SwiftSystem CONFIG REQUIRED)

add_subdirectory(Sources)
add_subdirectory(cmake/modules)
