if(NOT TARGET Intel::baremetal_concurrency)
  get_filename_component(
    _intel_baremetal_concurrency_prefix
    "${CMAKE_CURRENT_LIST_DIR}/../.."
    ABSOLUTE)
  add_library(Intel::baremetal_concurrency INTERFACE IMPORTED)
  set_target_properties(Intel::baremetal_concurrency PROPERTIES
    INTERFACE_COMPILE_FEATURES cxx_std_23
    INTERFACE_INCLUDE_DIRECTORIES
      "${_intel_baremetal_concurrency_prefix}/include")
  unset(_intel_baremetal_concurrency_prefix)
endif()
