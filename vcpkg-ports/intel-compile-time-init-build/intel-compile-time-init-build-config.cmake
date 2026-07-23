include(CMakeFindDependencyMacro)
find_dependency(Boost 1.91 CONFIG REQUIRED COMPONENTS mp11)
find_dependency(fmt CONFIG REQUIRED)
find_dependency(intel-cpp-baremetal-concurrency CONFIG REQUIRED)
find_dependency(intel-cpp-baremetal-senders-and-receivers CONFIG REQUIRED)
find_dependency(intel-cpp-std-extensions CONFIG REQUIRED)

if(NOT TARGET cib::nexus)
  get_filename_component(
    _intel_cib_prefix
    "${CMAKE_CURRENT_LIST_DIR}/../.."
    ABSOLUTE)
  add_library(cib::nexus INTERFACE IMPORTED)
  set_target_properties(cib::nexus PROPERTIES
    INTERFACE_COMPILE_FEATURES cxx_std_20
    INTERFACE_INCLUDE_DIRECTORIES "${_intel_cib_prefix}/include"
    INTERFACE_LINK_LIBRARIES "Boost::mp11;stdx::stdx")
  add_library(cib::cib INTERFACE IMPORTED)
  set_target_properties(cib::cib PROPERTIES
    INTERFACE_COMPILE_FEATURES cxx_std_20
    INTERFACE_INCLUDE_DIRECTORIES "${_intel_cib_prefix}/include"
    INTERFACE_LINK_LIBRARIES
      "Boost::mp11;fmt::fmt-header-only;Intel::baremetal_async;Intel::baremetal_concurrency;stdx::stdx")
  unset(_intel_cib_prefix)
endif()
