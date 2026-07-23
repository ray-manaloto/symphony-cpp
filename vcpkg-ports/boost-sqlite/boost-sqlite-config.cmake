include(CMakeFindDependencyMacro)

find_dependency(Boost CONFIG COMPONENTS headers)
find_dependency(SQLite3)

include("${CMAKE_CURRENT_LIST_DIR}/boost-sqlite-targets.cmake")
