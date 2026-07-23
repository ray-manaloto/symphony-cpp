cmake_minimum_required(VERSION 3.28)
project(symphony_cpp VERSION 0.1.0 LANGUAGES CXX)

include(CTest)
include(cmake/Dependencies.cmake)
option(SYMPHONY_ENABLE_REFLECTION "Compile C++26 reflection facilities" OFF)
option(SYMPHONY_WARNINGS_AS_ERRORS "Treat warnings as errors" ON)

set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_library(symphony_options INTERFACE)
target_compile_options(symphony_options INTERFACE
  $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>
  $<$<AND:$<BOOL:${SYMPHONY_WARNINGS_AS_ERRORS}>,$<CXX_COMPILER_ID:GNU,Clang>>:-Werror>)

add_library(symphony_reflection_options INTERFACE)
if(SYMPHONY_ENABLE_REFLECTION)
  target_compile_options(symphony_reflection_options INTERFACE
    $<$<CXX_COMPILER_ID:GNU>:-freflection>
    $<$<CXX_COMPILER_ID:Clang>:-freflection-latest>)
  target_compile_definitions(symphony_reflection_options INTERFACE SYMPHONY_ENABLE_REFLECTION=1)
endif()

add_subdirectory(src)
if(BUILD_TESTING)
  add_subdirectory(tests)
endif()
