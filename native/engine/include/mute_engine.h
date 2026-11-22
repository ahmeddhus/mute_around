/*
 * mute_engine.h — the public C ABI of the Mute Around real-time audio engine.
 *
 * This is the ONLY interface between Dart and native code. It uses plain C
 * types, never calls back into Dart and never lets exceptions cross it.
 * Dart bindings are generated from this file with ffigen
 * (`dart run tool/ffigen.dart` → lib/core/native/mute_engine.ffigen.dart).
 *
 * Versioning: `me_abi_version()` returns (MAJOR << 16) | MINOR. Dart refuses
 * to run against a library whose MAJOR differs from the one it was built for.
 * Bump MINOR for additive changes, MAJOR for anything that breaks callers.
 *
 * Threading: every function is safe to call from one control thread (the Dart
 * isolate). None blocks for more than ~100 ms (device open/close). The
 * `me_get_*` getters are wait-free and may be bound as FFI leaf calls.
 *
 * Strings are UTF-8 and NUL-terminated. Output strings go into caller-provided
 * buffers and are truncated safely.
 *
 * Call order:
 *   create → (list_devices | set_*)* → start
 *          → (set_* | get_* | list_devices | switch_input)* → stop → destroy
 * `start` while running returns ME_ERR_STATE. `destroy` is valid in any state.
 *
 * Test hook: if the environment variable MUTE_ENGINE_BACKEND is set to "null"
 * when `me_engine_create` runs, the engine uses miniaudio's null backend
 * (virtual capture and playback devices, no hardware). It is read once in
 * `me_engine_create`, never on the audio path.
 */
#ifndef MUTE_ENGINE_H
#define MUTE_ENGINE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define ME_API __declspec(dllexport)
#else
#define ME_API __attribute__((visibility("default")))
#endif

#define ME_ABI_VERSION_MAJOR 1
#define ME_ABI_VERSION_MINOR 0

/** Size of `me_device_info.id`, including the terminating NUL. */
#define ME_DEVICE_ID_MAX 256
/** Size of `me_device_info.name`, including the terminating NUL. */
#define ME_DEVICE_NAME_MAX 256

/** Result of every fallible call. ME_OK is 0; errors are negative. */
typedef int32_t me_result;
enum {
    ME_OK = 0,
    /** A required pointer was NULL or a value was out of range. */
    ME_ERR_INVALID_ARG = -1,
    /** The requested device id is not present. */
    ME_ERR_NOT_FOUND = -2,
    /** The OS refused microphone access. */
    ME_ERR_PERMISSION_DENIED = -3,
    /** A device failed to open or start. */
    ME_ERR_DEVICE = -4,
    /** The DeepFilterNet model failed to load. */
    ME_ERR_MODEL = -5,
    /** The call is not allowed in the current state (wrong call order). */
    ME_ERR_STATE = -6,
};

/*
 * Enumerations crossing the ABI are int32_t typedefs with anonymous enum
 * constants, because the size of a C enum type is implementation-defined.
 */

/** Engine run state, as reported by `me_get_status`. */
typedef int32_t me_status;
enum {
    ME_STATUS_STOPPED = 0,
    /** Capturing, denoising and writing to the sink. */
    ME_STATUS_RUNNING = 1,
    /** Running, but passing raw audio because the user asked for it. */
    ME_STATUS_BYPASSED_USER = 2,
    /** Running, but passing raw audio because the CPU can't keep up. */
    ME_STATUS_BYPASSED_OVERLOAD = 3,
    /** The capture device stopped; the sink receives silence. */
    ME_STATUS_DEVICE_DISCONNECTED = 4,
    ME_STATUS_ERROR = 5,
};

/** Noise-suppression strength; maps to a max attenuation of 12/24/100 dB. */
typedef int32_t me_strength;
enum {
    ME_STRENGTH_LOW = 0,
    ME_STRENGTH_MEDIUM = 1,
    ME_STRENGTH_HIGH = 2,
};

typedef int32_t me_device_kind;
enum {
    ME_DEVICE_CAPTURE = 0,
    ME_DEVICE_PLAYBACK = 1,
};

/** One audio device. `id` is stable across restarts (Core Audio UID / WASAPI endpoint id). */
typedef struct {
    char id[ME_DEVICE_ID_MAX];
    char name[ME_DEVICE_NAME_MAX];
    /** 1 if this is the OS default device of its kind. */
    uint8_t is_default;
} me_device_info;

/** Signal levels in dBFS, clamped to [-90, 0]. */
typedef struct {
    float input_peak_db;
    float input_rms_db;
    float output_peak_db;
    float output_rms_db;
} me_levels;

/** Diagnostics counters. */
typedef struct {
    /** Number of 10 ms frames processed; wraps around. */
    uint32_t frames_processed;
    /** Rolling average processing time per 10 ms frame, in milliseconds. */
    float avg_process_ms;
    /** Estimated capture → sink latency, in milliseconds. */
    float estimated_latency_ms;
    /** Times the sink had to output silence because no audio was ready. */
    uint32_t underruns;
    /** Times the engine entered overload bypass. */
    uint32_t overload_events;
} me_stats;

/** Opaque engine handle. */
typedef struct me_engine me_engine;

/** Returns (ME_ABI_VERSION_MAJOR << 16) | ME_ABI_VERSION_MINOR. */
ME_API uint32_t me_abi_version(void);

/**
 * Creates an engine and loads the DeepFilterNet model. Does not open devices.
 *
 * `model_path` is the path of a DFN model tarball (.tar.gz), or NULL to use
 * the model embedded in the library. On success `*out` receives the handle;
 * on failure it is set to NULL. Defaults after create: Medium strength,
 * AGC on, bypass off.
 */
ME_API me_result me_engine_create(const char* model_path, me_engine** out);

/** Stops the engine if running and frees everything. Safe on NULL. */
ME_API void me_engine_destroy(me_engine* engine);

/**
 * Lists capture or playback devices. Fills up to `cap` entries of `buf`
 * (which may be NULL when `cap` is 0) and returns the total number of
 * devices, which may exceed `cap`, or a negative `me_result`.
 */
ME_API int32_t me_list_devices(me_engine* engine, me_device_kind kind, me_device_info* buf,
                               int32_t cap);

/**
 * Opens the capture device (`capture_id`, or the OS default input when NULL)
 * and the sink (`sink_id`, or the OS default output when NULL), and starts
 * processing. Returns ME_ERR_STATE if already running, ME_ERR_NOT_FOUND for
 * an unknown id, ME_ERR_PERMISSION_DENIED when the OS refuses the microphone.
 */
ME_API me_result me_engine_start(me_engine* engine, const char* capture_id, const char* sink_id);

/**
 * Swaps the capture device while the sink keeps running (it outputs silence
 * meanwhile). `capture_id` NULL means the OS default input. Requires a
 * running engine.
 */
ME_API me_result me_engine_switch_input(me_engine* engine, const char* capture_id);

/** Stops devices and the processing thread. Returns ME_ERR_STATE when not running. */
ME_API me_result me_engine_stop(me_engine* engine);

/**
 * User bypass (pass raw audio). Crossfades over 10 ms. Atomic store; valid
 * in any state after create.
 */
ME_API void me_set_bypass(me_engine* engine, uint8_t on);

/**
 * Automatic gain control on/off (speech-gated, target -18 dBFS; the -1 dBFS
 * limiter stays on). Atomic store; valid in any state after create.
 */
ME_API void me_set_agc(me_engine* engine, uint8_t on);

/**
 * Suppression strength (max attenuation 12 / 24 / 100 dB), applied at the
 * next frame. Valid in any state after create.
 */
ME_API void me_set_strength(me_engine* engine, me_strength strength);

/**
 * Current status. Wait-free. While running, the user's bypass is reported
 * before an automatic (overload) one. Returns ME_STATUS_ERROR for a NULL
 * engine.
 */
ME_API me_status me_get_status(me_engine* engine);

/**
 * Current input (raw) and output levels in dBFS, -90..0: peak with a 300 ms
 * fall, RMS over ~50 ms. Silence when stopped or no audio arrives. Wait-free.
 */
ME_API void me_get_levels(me_engine* engine, me_levels* out);

/** Diagnostics counters. Wait-free. */
ME_API void me_get_stats(me_engine* engine, me_stats* out);

/**
 * Copies a human-readable (English) description of the last error into
 * `buf` (NUL-terminated, truncated to `cap`). Returns ME_OK, or
 * ME_ERR_INVALID_ARG for a NULL engine or buffer.
 */
ME_API me_result me_last_error(me_engine* engine, char* buf, int32_t cap);

#ifdef __cplusplus
}
#endif

#endif /* MUTE_ENGINE_H */
