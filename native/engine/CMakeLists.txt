# Native test build for the Mute Around engine.
#
# The app itself builds the engine with the Dart build hook (hook/build.dart);
# this CMake project exists so the C code can be unit- and fixture-tested
# with CTest:
#
#   cmake -S native/engine -B build/native-tests -DCMAKE_BUILD_TYPE=Release
#   cmake --build build/native-tests
#   ctest --test-dir build/native-tests --output-on-failure
cmake_minimum_required(VERSION 3.24)
project(mute_engine C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# --- libDF shim (Rust) ---------------------------------------------------
find_program(CARGO cargo HINTS "$ENV{HOME}/.cargo/bin" /opt/homebrew/opt/rustup/bin REQUIRED)
set(MDF_DIR "${CMAKE_CURRENT_SOURCE_DIR}/dfshim")
# The cargo invocation below mirrors hook/build.dart's exactly (same
# --target triple, --release, --locked and MACOSX_DEPLOYMENT_TARGET), so
# both can share a --target-dir and DeepFilterNet (libDF + tract) compiles
# once. CI points MUTE_DF_CARGO_TARGET_DIR at the hook's target dir,
# .dart_tool/hooks_runner/shared/mute_around/build/cargo, after
# `flutter test` has built it. If the two invocations ever differ, cargo
# rebuilds and overwrites the other's output on every alternate build, so
# change both together. The hooks runner also drops most environment
# variables before running the hook (RUSTFLAGS, and CC/CFLAGS/AR, which
# tract-linalg's build script tracks), so don't set those for this build.
# A relative path is taken from the repository root.
set(MUTE_DF_CARGO_TARGET_DIR "${CMAKE_CURRENT_BINARY_DIR}/cargo" CACHE PATH
  "cargo --target-dir for the DeepFilterNet shim (relative: from the repo root)")
file(TO_CMAKE_PATH "${MUTE_DF_CARGO_TARGET_DIR}" MDF_TARGET_DIR)
cmake_path(ABSOLUTE_PATH MDF_TARGET_DIR
  BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../.." NORMALIZE)

# Same triple as _rustTarget() in hook/build.dart.
if(APPLE)
  if(CMAKE_OSX_ARCHITECTURES)
    set(MDF_ARCH "${CMAKE_OSX_ARCHITECTURES}")
  else()
    set(MDF_ARCH "${CMAKE_HOST_SYSTEM_PROCESSOR}")
  endif()
  set(MDF_OS apple-darwin)
elseif(WIN32)
  if(CMAKE_GENERATOR_PLATFORM)
    set(MDF_ARCH "${CMAKE_GENERATOR_PLATFORM}")
  else()
    set(MDF_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  endif()
  set(MDF_OS pc-windows-msvc)
else()
  message(FATAL_ERROR "Mute Around supports macOS and Windows only")
endif()
string(TOLOWER "${MDF_ARCH}" MDF_ARCH)
if(MDF_ARCH MATCHES "^(arm64|aarch64)$")
  set(MDF_ARCH aarch64)
elseif(MDF_ARCH MATCHES "^(x86_64|amd64|x64)$")
  set(MDF_ARCH x86_64)
else()
  message(FATAL_ERROR "No Rust target for architecture '${MDF_ARCH}'")
endif()
set(MUTE_DF_RUST_TARGET "${MDF_ARCH}-${MDF_OS}" CACHE STRING
  "cargo --target triple for the DeepFilterNet shim")

if(WIN32)
  set(MDF_LIB "${MDF_TARGET_DIR}/${MUTE_DF_RUST_TARGET}/release/mute_df.lib")
else()
  set(MDF_LIB "${MDF_TARGET_DIR}/${MUTE_DF_RUST_TARGET}/release/libmute_df.a")
endif()
# cargo needs rustc next to it on PATH. Homebrew's rustup keeps both in a
# folder that isn't on PATH, so prepend it there. On Windows, rustup puts
# both on PATH already, and wrapping the call in `cmake -E env` with the
# whole Windows PATH broke the build ("no such file or directory").
if(WIN32)
  set(CARGO_CMD "${CARGO}")
else()
  # The hook passes "<major>.0" of the app's deployment target
  # (macos/Runner.xcodeproj: MACOSX_DEPLOYMENT_TARGET = 13.0).
  set(MUTE_DF_MACOSX_DEPLOYMENT_TARGET "13.0" CACHE STRING
    "MACOSX_DEPLOYMENT_TARGET for the DeepFilterNet shim; must match the hook's")
  get_filename_component(CARGO_DIR "${CARGO}" DIRECTORY)
  set(CARGO_CMD "${CMAKE_COMMAND}" -E env "PATH=${CARGO_DIR}:$ENV{PATH}"
    "MACOSX_DEPLOYMENT_TARGET=${MUTE_DF_MACOSX_DEPLOYMENT_TARGET}" "${CARGO}")
endif()
add_custom_command(
  OUTPUT "${MDF_LIB}"
  COMMAND ${CARGO_CMD} build --release --locked --manifest-path "${MDF_DIR}/Cargo.toml"
          --target "${MUTE_DF_RUST_TARGET}" --target-dir "${MDF_TARGET_DIR}"
  DEPENDS "${MDF_DIR}/Cargo.toml" "${MDF_DIR}/Cargo.lock" "${MDF_DIR}/src/lib.rs"
          "${MDF_DIR}/src/rt_alloc.rs"
  COMMENT "Building the DeepFilterNet shim with cargo"
  VERBATIM)
add_custom_target(mute_df_build DEPENDS "${MDF_LIB}")
add_library(mute_df STATIC IMPORTED GLOBAL)
set_target_properties(mute_df PROPERTIES IMPORTED_LOCATION "${MDF_LIB}")
add_dependencies(mute_df mute_df_build)
if(APPLE)
  target_link_libraries(mute_df INTERFACE "-framework CoreFoundation" "-framework Security")
elseif(WIN32)
  # synchronization: WaitOnAddress / WakeByAddress*, used by Rust std's locks.
  target_link_libraries(mute_df INTERFACE ws2_32 userenv ntdll bcrypt advapi32 synchronization)
endif()

# --- Engine --------------------------------------------------------------
add_library(mute_engine_core STATIC
  src/engine.c
  src/devices.c
  src/processing.c
  src/agc.c
  src/limiter.c
  src/crossfade.c
  src/overload.c
  src/levels.c
  src/drift.c
  src/ring_buffer.c
  src/rt_thread.c
  src/miniaudio_impl.c)
target_include_directories(mute_engine_core
  PUBLIC include src
  PRIVATE third_party/miniaudio)
target_include_directories(mute_engine_core SYSTEM PUBLIC third_party/miniaudio)
target_link_libraries(mute_engine_core PUBLIC mute_df)
if(APPLE)
  target_link_libraries(mute_engine_core PUBLIC
    "-framework CoreAudio" "-framework AudioToolbox" "-framework CoreFoundation")
elseif(WIN32)
  target_link_libraries(mute_engine_core PUBLIC ole32 avrt)
else()
  target_link_libraries(mute_engine_core PUBLIC m pthread)
endif()
if(MSVC)
  target_compile_options(mute_engine_core PRIVATE /W4)
  # <stdatomic.h> is opt-in on MSVC. PUBLIC: the tests include the same
  # headers (ring_buffer.h, levels.h).
  target_compile_options(mute_engine_core PUBLIC /experimental:c11atomics)
else()
  target_compile_options(mute_engine_core PRIVATE -Wall -Wextra)
endif()

enable_testing()
add_subdirectory(tests)
