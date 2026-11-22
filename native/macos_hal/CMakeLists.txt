# Builds MuteAround.driver, the macOS virtual microphone (Audio Server plug-in).
#
#   cmake -S native/macos_hal -B build/macos_hal -DCMAKE_BUILD_TYPE=Release
#   cmake --build build/macos_hal
#
# The Xcode build phase (macos/scripts/build_hal.sh) runs this and copies the
# bundle into the app's Contents/Resources for the setup flow to install.
cmake_minimum_required(VERSION 3.24)

set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "")
set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "")
project(MuteAroundHAL CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(DRIVER_NAME "MuteAround")
set(DRIVER_VERSION "1.0.0")

# libASPL, built and installed into the build tree.
include(ExternalProject)
set(LIBASPL_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/libASPL-prefix")
ExternalProject_Add(libASPL_build
  SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/libASPL"
  BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/libASPL-build"
  INSTALL_DIR "${LIBASPL_PREFIX}"
  CMAKE_ARGS
    -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_OSX_ARCHITECTURES=${CMAKE_OSX_ARCHITECTURES}
    -DCMAKE_OSX_DEPLOYMENT_TARGET=${CMAKE_OSX_DEPLOYMENT_TARGET}
    -DBUILD_TESTING=OFF
  BUILD_BYPRODUCTS "${LIBASPL_PREFIX}/lib/libASPL.a"
  LOG_CONFIGURE YES
  LOG_BUILD YES
  LOG_INSTALL YES)

# A MODULE library packed as a .driver bundle (Mach-O loadable bundle).
add_library(${DRIVER_NAME} MODULE src/plugin.cpp)
add_dependencies(${DRIVER_NAME} libASPL_build)
# SYSTEM: libASPL headers aren't ours, so their warnings are not reported.
target_include_directories(${DRIVER_NAME} SYSTEM PRIVATE "${LIBASPL_PREFIX}/include")
target_link_libraries(${DRIVER_NAME} PRIVATE
  "${LIBASPL_PREFIX}/lib/libASPL.a"
  "-framework CoreFoundation"
  "-framework CoreAudio")
target_compile_options(${DRIVER_NAME} PRIVATE -Wall -Wextra)

set_target_properties(${DRIVER_NAME} PROPERTIES
  OUTPUT_NAME "${DRIVER_NAME}"
  BUNDLE TRUE
  BUNDLE_EXTENSION "driver"
  PREFIX ""
  SUFFIX ""
  MACOSX_BUNDLE ON
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
  MACOSX_BUNDLE_BUNDLE_NAME "${DRIVER_NAME}"
  MACOSX_BUNDLE_BUNDLE_VERSION "${DRIVER_VERSION}"
  MACOSX_BUNDLE_SHORT_VERSION_STRING "${DRIVER_VERSION}"
  MACOSX_BUNDLE_GUI_IDENTIFIER "com.mutearound.virtualmic.driver"
  MACOSX_BUNDLE_COPYRIGHT "Mute Around contributors, MIT License")

# Ad-hoc signature: coreaudiod on Apple Silicon only loads signed code.
add_custom_command(TARGET ${DRIVER_NAME} POST_BUILD
  COMMAND codesign --force --sign - "$<TARGET_BUNDLE_DIR:${DRIVER_NAME}>"
  COMMENT "Ad-hoc signing ${DRIVER_NAME}.driver"
  VERBATIM)
