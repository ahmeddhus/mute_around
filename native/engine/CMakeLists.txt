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
set(MDF_TARGET_DIR "${CMAKE_CURRENT_BINARY_DIR}/cargo")
if(WIN32)
  set(MDF_LIB "${MDF_TARGET_DIR}/release/mute_df.lib")
else()
  set(MDF_LIB "${MDF_TARGET_DIR}/release/libmute_df.a")
endif()
# cargo needs rustc next to it on PATH (rustup keeps both in the same folder).
get_filename_component(CARGO_DIR "${CARGO}" DIRECTORY)
if(WIN32)
  set(CARGO_PATH "PATH=${CARGO_DIR};$ENV{PATH}")
else()
  set(CARGO_PATH "PATH=${CARGO_DIR}:$ENV{PATH}")
endif()
add_custom_command(
  OUTPUT "${MDF_LIB}"
  COMMAND "${CMAKE_COMMAND}" -E env "${CARGO_PATH}" "${CARGO}" build --release --locked --manifest-path "${MDF_DIR}/Cargo.toml"
          --target-dir "${MDF_TARGET_DIR}"
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
  target_link_libraries(mute_df INTERFACE ws2_32 userenv ntdll bcrypt advapi32)
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
else()
  target_compile_options(mute_engine_core PRIVATE -Wall -Wextra)
endif()

enable_testing()
add_subdirectory(tests)
