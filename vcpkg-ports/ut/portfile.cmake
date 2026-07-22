vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO openalgz/ut
  REF v1.2.0
  SHA512 dd5acfc244ec7a746cbffafc4739728cccef02f591ae714db22a20b7d5d70352aaade16ae92cca528ae4715a1f57952335e9cba184053b283562a28fca784994
  HEAD_REF main)

vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}"
  OPTIONS
    -DBUILD_TESTING=OFF
    -DUT_COMPILE_TIME=OFF
    -DUT_ENABLE_MODULES=OFF)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share/ut)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
