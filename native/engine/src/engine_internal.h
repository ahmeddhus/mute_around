/*
 * Engine internals shared by engine.c, devices.c and processing.c, plus the
 * offline hooks used by the native tests. Not part of the public ABI.
 */
#ifndef ME_ENGINE_INTERNAL_H
#define ME_ENGINE_INTERNAL_H

#include <stdatomic.h>
#include <stddef.h>

#include "agc.h"
#include "crossfade.h"
#include "drift.h"
#include "levels.h"
#include "limiter.h"
#include "miniaudio_config.h"
#include "mute_df.h"
#include "mute_engine.h"
#include "overload.h"
#include "ring_buffer.h"
#include "rt_thread.h"

#define ME_SAMPLE_RATE 48000
/* DFN3 hop: 10 ms at 48 kHz. */
#define ME_HOP 480
/* Device period: 2.5 ms. */
#define ME_PERIOD_FRAMES 120
/* ~170 ms per ring; normal operation uses a small fraction of it. */
#define ME_RING_CAPACITY 8192
/* The playback side starts reading once a hop plus the drift target is queued. */
#define ME_PRIME_FILL (ME_HOP + ME_DRIFT_TARGET)
/* Above this the input ring is resynchronised to one hop (after a stall). */
#define ME_INPUT_MAX_FILL (4 * ME_HOP)
/* Above this a whole output hop is dropped (after a stall). */
#define ME_OUTPUT_MAX_FILL (ME_DRIFT_TARGET + 4 * ME_HOP)
/* DFN3 low-latency model: STFT window minus hop, no lookahead. */
#define ME_DFN_DELAY_MS 10.0f
#define ME_ERROR_MAX 512
/* Hop period in milliseconds. */
#define ME_HOP_MS (1000.0f * ME_HOP / ME_SAMPLE_RATE)
/* With this much input waiting, an output underrun means we fell behind. */
#define ME_BACKLOG_FRAMES (2 * ME_HOP)
/* No hop for this long: the meters show silence. */
#define ME_LEVELS_IDLE_US 100000

struct me_engine {
    /* Owned by the control thread. */
    ma_context context;
    int null_backend;
    int running;
    int capture_open;
    int playback_open;
    ma_device capture;
    ma_device playback;
    me_thread proc_thread;
    char last_error[ME_ERROR_MAX];

    /* DeepFilterNet state; used only by the processing thread while running. */
    MdfState* dfn;

    /* Settings: written by the control thread, read once per hop. */
    _Atomic uint8_t bypass;
    _Atomic uint8_t agc;
    _Atomic int32_t strength;

    /* Run state. */
    _Atomic int32_t status;       /* STOPPED, RUNNING, DEVICE_DISCONNECTED or ERROR */
    _Atomic int proc_run;         /* processing thread keeps looping while set */
    _Atomic int capture_stopping; /* set while we stop the capture device ourselves */
    _Atomic int playback_primed;
    _Atomic int overloaded; /* mirror of `overload.active` for me_get_status */

    /* Audio path. */
    me_ring ring_in;
    me_ring ring_out;
    me_drift drift; /* processing thread only */
    /* Processing-thread scratch: one hop plus room for a duplicated sample. */
    float in_hop[ME_HOP];
    float out_hop[ME_HOP + 1];

    /* DSP after DFN; processing thread only (or the offline test path).
     * See me_process_hop for the order. */
    float proc_hop[ME_HOP];  /* DFN (+ AGC) output */
    float raw_delay[ME_HOP]; /* previous input hop: raw audio aligned with DFN's delay */
    int applied_strength;    /* strength last given to DFN; -1 forces an update */
    me_agc agc_state;
    me_limiter limiter;
    me_crossfade xfade;
    me_overload overload;
    uint32_t seen_underruns;
    me_levels_state levels; /* written here, read by me_get_levels */

    /* Stats (atomics; floats stored as their bit patterns). */
    _Atomic uint32_t frames_processed;
    _Atomic uint32_t underruns;
    _Atomic uint32_t overload_events;
    _Atomic uint32_t avg_process_ms_bits;
    _Atomic uint32_t avg_out_fill_bits;
};

/* Stores/loads a float in an _Atomic uint32_t. */
void me_atomic_store_float(_Atomic uint32_t* slot, float value);
float me_atomic_load_float(_Atomic uint32_t* slot);

/* Writes a formatted message into engine->last_error (control thread). */
void me_set_error(me_engine* engine, const char* fmt, ...);

/* --- devices.c --- */

/* Serialises a miniaudio device id into a stable string. */
void me_device_id_to_string(const ma_context* context, const ma_device_id* id, char* out,
                            size_t cap);

/*
 * Looks up `id` among devices of `type`. Returns ME_OK and fills `out`, or
 * ME_ERR_NOT_FOUND / ME_ERR_DEVICE.
 */
me_result me_find_device(me_engine* engine, ma_device_type type, const char* id,
                         ma_device_id* out);

/* --- processing.c --- */

/* Processing thread entry point. */
void me_processing_main(void* engine);

/*
 * Resets the per-hop DSP state (AGC, limiter, crossfade, overload, meters)
 * for a fresh start. Control thread, while the processing thread isn't
 * running.
 */
void me_processing_reset(me_engine* engine);

/* Maximum noise attenuation for a strength preset, in dB. */
float me_strength_attenuation_db(int32_t strength);

/*
 * Processes one hop of ME_HOP samples: DFN → AGC → bypass crossfade →
 * limiter → meters. Real-time safe once the thread has entered the DFN pool
 * (me_internal_rt_enter).
 */
void me_process_hop(me_engine* engine, const float* in, float* out);

/* --- Offline hooks for native tests (not exported to Dart) --- */

/* Routes this thread's DFN allocations to the engine's real-time pool. */
void me_internal_rt_enter(me_engine* engine);
void me_internal_rt_leave(void);

/* System-heap fallbacks of the DFN pool (should stay 0). */
size_t me_internal_rt_fallbacks(void);

/* Current AGC gain in dB (offline tests). */
float me_internal_agc_gain_db(const me_engine* engine);

/*
 * Processes `frames` samples from `in` to `out` on the calling thread, in
 * hops, exactly as the processing thread would (without devices or drift
 * correction). A partial last hop is zero-padded. Returns ME_ERR_STATE while
 * the engine is running.
 */
me_result me_internal_process_buffer(me_engine* engine, const float* in, float* out,
                                     size_t frames);

#endif /* ME_ENGINE_INTERNAL_H */
