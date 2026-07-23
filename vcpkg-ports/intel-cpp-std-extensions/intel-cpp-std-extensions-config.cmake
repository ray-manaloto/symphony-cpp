include(CMakeFindDependencyMacro)
find_dependency(Boost 1.91 CONFIG REQUIRED COMPONENTS mp11)
find_dependency(fmt CONFIG REQUIRED)
find_dependency(intel-cpp-baremetal-concurrency CONFIG REQUIRED)

if(NOT TARGET stdx::stdx)
  get_filename_component(
    _intel_stdx_prefix
    "${CMAKE_CURRENT_LIST_DIR}/../.."
    ABSOLUTE)
  add_library(stdx::stdx INTERFACE IMPORTED)
  set_target_properties(stdx::stdx PROPERTIES
    INTERFACE_COMPILE_FEATURES cxx_std_23
    INTERFACE_INCLUDE_DIRECTORIES "${_intel_stdx_prefix}/include"
    INTERFACE_LINK_LIBRARIES
      "Boost::mp11;fmt::fmt-header-only;Intel::baremetal_concurrency")
  unset(_intel_stdx_prefix)
endif()
