/*
 * Level metering: peak and RMS of the raw input and the
 * processed output, per hop, smoothed so a 30 Hz reader doesn't miss short
 * peaks. Written by the processing thread, read wait-free by Dart through
 * me_get_levels (floats stored as bit patterns in atomics).
 */
#ifndef ME_LEVELS_H
#define ME_LEVELS_H

#include <stdatomic.h>
#include <stddef.h>
#include <stdint.h>

#include "mute_engine.h"

#define ME_LEVEL_FLOOR_DB (-90.0f)
/* Peak falls back with this time constant; RMS is averaged over it. */
#define ME_LEVEL_PEAK_DECAY_MS 300.0f
#define ME_LEVEL_RMS_MS 50.0f

typedef struct {
    float peak;  /* linear, processing thread only */
    float power; /* mean square, processing thread only */
} me_meter;

typedef struct {
    me_meter in, out;
    float peak_decay; /* per-hop peak multiplier */
    float rms_alpha;  /* per-hop power smoothing */
    _Atomic uint32_t in_peak_db, in_rms_db, out_peak_db, out_rms_db;
} me_levels_state;

/* Sets the meters to silence; `hop_ms` is the update period. */
void me_levels_init(me_levels_state* lv, float hop_ms);

/* Processing thread: measures one hop of input and output and publishes. */
void me_levels_update(me_levels_state* lv, const float* in, const float* out, size_t n);

/* Processing/control thread: publishes silence (no audio flowing). */
void me_levels_silence(me_levels_state* lv);

/* Any thread, wait-free. */
void me_levels_read(me_levels_state* lv, me_levels* out);

#endif /* ME_LEVELS_H */
