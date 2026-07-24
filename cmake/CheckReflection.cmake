include(CheckCXXSourceCompiles)

if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  set(_symphony_reflection_probe_flags "-freflection")
elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  set(_symphony_reflection_probe_flags
    "-freflection -fexpansion-statements")
else()
  message(FATAL_ERROR
    "Reflection is unsupported for ${CMAKE_CXX_COMPILER_ID}")
endif()

set(_symphony_saved_required_flags "${CMAKE_REQUIRED_FLAGS}")
string(APPEND CMAKE_REQUIRED_FLAGS
  " ${_symphony_reflection_probe_flags}")
set(_symphony_reflection_probe_path
  "${PROJECT_SOURCE_DIR}/tests/fixtures/p2996_reflection_probe.cpp")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
  "${_symphony_reflection_probe_path}")
file(READ "${_symphony_reflection_probe_path}"
  _symphony_reflection_probe_source)
unset(SYMPHONY_CXX26_REFLECTION_SUPPORTED CACHE)
check_cxx_source_compiles(
  "${_symphony_reflection_probe_source}"
  SYMPHONY_CXX26_REFLECTION_SUPPORTED)
set(CMAKE_REQUIRED_FLAGS "${_symphony_saved_required_flags}")
unset(_symphony_reflection_probe_source)
unset(_symphony_reflection_probe_path)
unset(_symphony_saved_required_flags)
unset(_symphony_reflection_probe_flags)

if(NOT SYMPHONY_CXX26_REFLECTION_SUPPORTED)
  message(FATAL_ERROR
    "${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION} failed the "
    "required C++26 reflection and expansion-statement probe")
endif()
