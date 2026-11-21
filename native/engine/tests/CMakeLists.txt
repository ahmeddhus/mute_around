# CTest suite: unit tests and offline WAV-fixture tests.
set(FIXTURES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/fixtures")

function(me_add_test name)
  add_executable(${name} ${name}.c ${ARGN})
  target_link_libraries(${name} PRIVATE mute_engine_core)
  target_include_directories(${name} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}
                                             ${CMAKE_CURRENT_SOURCE_DIR}/third_party)
  target_compile_definitions(${name} PRIVATE ME_FIXTURES_DIR="${FIXTURES_DIR}")
  add_test(NAME ${name} COMMAND ${name})
endfunction()

me_add_test(test_ring_buffer)
me_add_test(test_drift)
me_add_test(test_denoise_fixtures wav_util.c)
me_add_test(test_agc wav_util.c)
me_add_test(test_crossfade)
me_add_test(test_overload)

# Allocation counter: its own shared library on macOS, because dyld never
# interposes calls made inside the interposing image (see alloc_counter.h).
if(APPLE)
  add_library(alloc_counter SHARED alloc_counter.c)
  me_add_test(test_no_alloc)
  target_link_libraries(test_no_alloc PRIVATE alloc_counter)
elseif(WIN32)
  me_add_test(test_no_alloc alloc_counter.c)
endif()
