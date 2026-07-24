include(CheckCXXSourceCompiles)
include(CMakePushCheckState)

cmake_push_check_state(RESET)
set(CMAKE_REQUIRED_FLAGS
  "-fsanitize=realtime -fno-omit-frame-pointer -Werror=function-effects -Werror=perf-constraint-implies-noexcept")
set(CMAKE_REQUIRED_LINK_OPTIONS
  -fsanitize=realtime
  -fno-omit-frame-pointer)

check_cxx_source_compiles(
  [[
    #include <sanitizer/rtsan_interface.h>

    #ifndef __has_feature
    #error "Clang feature detection is unavailable"
    #elif !__has_feature(realtime_sanitizer)
    #error "RealtimeSanitizer instrumentation is unavailable"
    #endif

    void nonblocking_probe() noexcept [[clang::nonblocking]] {}

    int main() {
      nonblocking_probe();
      return 0;
    }
  ]]
  SYMPHONY_RTSAN_AVAILABLE)

check_cxx_source_compiles(
  [[
    void missing_noexcept() [[clang::nonblocking]] {}

    int main() {
      missing_noexcept();
      return 0;
    }
  ]]
  SYMPHONY_RTSAN_ACCEPTED_MISSING_NOEXCEPT)

check_cxx_source_compiles(
  [[
    void allocating_operation() noexcept [[clang::nonblocking]] {
      auto* value = new int{42};
      delete value;
    }

    int main() {
      allocating_operation();
      return 0;
    }
  ]]
  SYMPHONY_RTSAN_ACCEPTED_ALLOCATION)

cmake_pop_check_state()

if(NOT SYMPHONY_RTSAN_AVAILABLE)
  message(FATAL_ERROR
    "Pinned Clang lacks a usable compiler-rt RealtimeSanitizer runtime or interface")
endif()
if(SYMPHONY_RTSAN_ACCEPTED_MISSING_NOEXCEPT)
  message(FATAL_ERROR
    "Clang did not enforce noexcept on a nonblocking function")
endif()
if(SYMPHONY_RTSAN_ACCEPTED_ALLOCATION)
  message(FATAL_ERROR
    "Clang did not reject allocation in a nonblocking function")
endif()
