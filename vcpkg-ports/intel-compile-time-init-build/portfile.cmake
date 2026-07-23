vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO intel/compile-time-init-build
  REF f9b4cc5e5af9703ac569f3eb988af8c7e29fe032
  SHA512 e03de5000b6d65e805b4a48e345ce9dab1b8feefddfea364c40263d1db57cc598987cad2a6260dc851351f1f27acc4e4b9e5c86d78a73ae14d909ecee7768ec0)

file(INSTALL "${SOURCE_PATH}/include/"
  DESTINATION "${CURRENT_PACKAGES_DIR}/include")
file(INSTALL
  "${CURRENT_PORT_DIR}/intel-compile-time-init-build-config.cmake"
  DESTINATION "${CURRENT_PACKAGES_DIR}/share/intel-compile-time-init-build")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
