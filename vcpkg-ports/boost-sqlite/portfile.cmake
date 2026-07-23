vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO klemens-morgenstern/sqlite
  REF 6cf149d052dc30cd8715586284ffe398df55d2e9
  SHA512 54b0e8ce8667cd7030d2f0c4dfd288e24f633911ae4f2e3efacfc015705b74cc7ce16b74daf454f01ef4ec9347f76159fe36b5fd64605b3403de811e7d270f66
  HEAD_REF master)

vcpkg_replace_string(
  "${SOURCE_PATH}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.12...3.20)"
  "cmake_minimum_required(VERSION 3.12...3.20)\n\ninclude(GNUInstallDirs)")
vcpkg_replace_string(
  "${SOURCE_PATH}/CMakeLists.txt"
  "target_include_directories(boost_sqlite PUBLIC \"\${CMAKE_CURRENT_SOURCE_DIR}/include\")"
  "set_target_properties(boost_sqlite PROPERTIES EXPORT_NAME sqlite)\ntarget_include_directories(boost_sqlite PUBLIC\n        \"$<BUILD_INTERFACE:\${CMAKE_CURRENT_SOURCE_DIR}/include>\"\n        \"$<INSTALL_INTERFACE:\${CMAKE_INSTALL_INCLUDEDIR}>\")")
vcpkg_replace_string(
  "${SOURCE_PATH}/CMakeLists.txt"
  "    install(TARGETS boost_sqlite\n            RUNTIME DESTINATION \"\${CMAKE_INSTALL_BINDIR}\"\n            LIBRARY DESTINATION \"\${CMAKE_INSTALL_LIBDIR}\"\n            ARCHIVE DESTINATION \"\${CMAKE_INSTALL_LIBDIR}\"\n            )"
  "    install(TARGETS boost_sqlite\n            EXPORT boost-sqlite-targets\n            RUNTIME DESTINATION \"\${CMAKE_INSTALL_BINDIR}\"\n            LIBRARY DESTINATION \"\${CMAKE_INSTALL_LIBDIR}\"\n            ARCHIVE DESTINATION \"\${CMAKE_INSTALL_LIBDIR}\"\n            )\n    install(DIRECTORY \"\${CMAKE_CURRENT_SOURCE_DIR}/include/\"\n            DESTINATION \"\${CMAKE_INSTALL_INCLUDEDIR}\")\n    install(EXPORT boost-sqlite-targets\n            FILE boost-sqlite-targets.cmake\n            NAMESPACE Boost::\n            DESTINATION \"\${CMAKE_INSTALL_DATADIR}/boost-sqlite\")")

vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}"
  OPTIONS
    -DBUILD_TESTING=OFF
    -DBOOST_SQLITE_BUILD_TESTS=OFF
    -DBOOST_SQLITE_BUILD_EXAMPLES=OFF)
vcpkg_cmake_install()

file(INSTALL
  "${CURRENT_PORT_DIR}/boost-sqlite-config.cmake"
  DESTINATION "${CURRENT_PACKAGES_DIR}/share/boost-sqlite")
vcpkg_cmake_config_fixup(
  PACKAGE_NAME boost-sqlite
  CONFIG_PATH share/boost-sqlite)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
vcpkg_install_copyright(FILE_LIST "${CURRENT_PORT_DIR}/copyright")
