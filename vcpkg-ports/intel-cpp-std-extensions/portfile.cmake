vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO intel/cpp-std-extensions
  REF a35c5f2cb6d5180afd459495e9e26c279f1aa77a
  SHA512 031ca3a12d937b6a87ebbfdfc3fc00c431eeaa4605a4e9430a93a73ca65bbab826693e4d183def96bda7537a2d61d86776eb347daca7f7dd50b87f949a9ef766)

file(INSTALL "${SOURCE_PATH}/include/"
  DESTINATION "${CURRENT_PACKAGES_DIR}/include")
file(INSTALL
  "${CURRENT_PORT_DIR}/intel-cpp-std-extensions-config.cmake"
  DESTINATION "${CURRENT_PACKAGES_DIR}/share/intel-cpp-std-extensions")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
