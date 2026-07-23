vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO intel/cpp-baremetal-concurrency
  REF b8a486a3bd1d166128ebbdb8e88f7a43443a5e83
  SHA512 6a8dadb52146550699af105c711b0c1c51817479138a7e1d0a3554a2803729661ab171adebaa3965e2576e3a6bc3483924f276d703254544c64564f980dd8c52)

file(INSTALL "${SOURCE_PATH}/include/"
  DESTINATION "${CURRENT_PACKAGES_DIR}/include")
file(INSTALL
  "${CURRENT_PORT_DIR}/intel-cpp-baremetal-concurrency-config.cmake"
  DESTINATION
  "${CURRENT_PACKAGES_DIR}/share/intel-cpp-baremetal-concurrency")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
