vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO intel/cpp-baremetal-senders-and-receivers
  REF 3e3c8aaa1b0aa8035453050997ae25ab08d936f1
  SHA512 96211e240932ffb74c671de3e55bdf7e3327010848732c4dbb45287f5901d4d6ca72448d6651df796ba2d3da31ebb38643f456486a6400e68acbf8200887e53d)

file(INSTALL "${SOURCE_PATH}/include/"
  DESTINATION "${CURRENT_PACKAGES_DIR}/include")
file(INSTALL
  "${CURRENT_PORT_DIR}/intel-cpp-baremetal-senders-and-receivers-config.cmake"
  DESTINATION
  "${CURRENT_PACKAGES_DIR}/share/intel-cpp-baremetal-senders-and-receivers")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
