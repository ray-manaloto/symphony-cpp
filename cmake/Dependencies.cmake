include(FetchContent)

# yaml-cpp 0.8.0 predates CMake 4's removal of policy compatibility below 3.5.
set(CMAKE_POLICY_VERSION_MINIMUM 3.5 CACHE STRING "Minimum dependency policy compatibility" FORCE)

set(YAML_CPP_BUILD_CONTRIB OFF CACHE BOOL "" FORCE)
set(YAML_CPP_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(YAML_CPP_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(YAML_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
FetchContent_Declare(yaml_cpp
  URL https://github.com/jbeder/yaml-cpp/archive/f7320141120f720aecc4c32be25586e7da9eb978.tar.gz
  URL_HASH SHA256=2fd3bf695ccc056835a70dd6d3046312cc1004e8338b8b5c91646918a27b7ef6
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE)

set(JSON_BuildTests OFF CACHE BOOL "" FORCE)
FetchContent_Declare(nlohmann_json
  URL https://github.com/nlohmann/json/archive/65ee68451d8eb2b5f3a30b410476ab83deb3289b.tar.gz
  URL_HASH SHA256=13ef31d691947940a08909f8e0772f1d7d68e5da1678ee812a49c4bb0c996b2f
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE)

FetchContent_MakeAvailable(yaml_cpp nlohmann_json)

# GCC 17 no longer exposes fixed-width integers through yaml-cpp's incidental includes.
target_compile_options(yaml-cpp PRIVATE $<$<CXX_COMPILER_ID:GNU>:-include;cstdint>)
