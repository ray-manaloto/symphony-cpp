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
check_cxx_source_compiles(
  [=[
    #include <meta>
    #include <string_view>

    struct reflection_probe {
      int value;
    };

    consteval bool reflection_works() {
      static constexpr auto members =
          std::define_static_array(std::meta::nonstatic_data_members_of(
              ^^reflection_probe, std::meta::access_context::current()));
      static_assert(members.size() == 1);
      template for (constexpr auto member : members) {
        static_assert(
            std::meta::identifier_of(member) == std::string_view{"value"});
      }
      return true;
    }

    static_assert(reflection_works());

    int main() {}
  ]=]
  SYMPHONY_CXX26_REFLECTION_SUPPORTED)
set(CMAKE_REQUIRED_FLAGS "${_symphony_saved_required_flags}")
unset(_symphony_saved_required_flags)
unset(_symphony_reflection_probe_flags)

if(NOT SYMPHONY_CXX26_REFLECTION_SUPPORTED)
  message(FATAL_ERROR
    "${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION} failed the "
    "required C++26 reflection and expansion-statement probe")
endif()
