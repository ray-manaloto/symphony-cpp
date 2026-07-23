include(CMakeFindDependencyMacro)
find_dependency(Boost 1.91 CONFIG REQUIRED COMPONENTS mp11)
find_dependency(intel-cpp-baremetal-concurrency CONFIG REQUIRED)
find_dependency(intel-cpp-std-extensions CONFIG REQUIRED)

if(NOT TARGET Intel::baremetal_async)
  get_filename_component(
    _intel_baremetal_async_prefix
    "${CMAKE_CURRENT_LIST_DIR}/../.."
    ABSOLUTE)
  add_library(Intel::baremetal_async INTERFACE IMPORTED)
  set_target_properties(Intel::baremetal_async PROPERTIES
    INTERFACE_COMPILE_FEATURES cxx_std_20
    INTERFACE_INCLUDE_DIRECTORIES "${_intel_baremetal_async_prefix}/include"
    INTERFACE_LINK_LIBRARIES
      "Boost::mp11;Intel::baremetal_concurrency;stdx::stdx")
  unset(_intel_baremetal_async_prefix)
endif()
