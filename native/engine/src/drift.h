/*
 * Clock-drift correction for the output ring.
 *
 * The microphone and the sink run on independent clocks, so the output ring
 * slowly fills or drains. Once per hop, before writing, the processing thread
 * reports the ring's fill level. When the smoothed fill has stayed outside
 * the tolerance band for DRIFT_HOLD_HOPS hops, the corrector asks to drop or
 * duplicate ONE sample, only in a quiet hop so the edit is inaudible, and at
 * most once every DRIFT_COOLDOWN_HOPS hops.
 */
#ifndef ME_DRIFT_H
#define ME_DRIFT_H

#include <stddef.h>

/* Target fill (samples) just before the processing thread writes a hop: 5 ms. */
#define ME_DRIFT_TARGET 240
/* Too full above target + 240 (spec: ±240 samples). */
#define ME_DRIFT_HIGH (ME_DRIFT_TARGET + 240)
/*
 * Too empty below target / 2: the ring underruns at 0, so waiting for
 * target − 240 would only ever be caught by an audible underrun.
 */
#define ME_DRIFT_LOW (ME_DRIFT_TARGET / 2)
/* The condition must hold for 1 s (100 hops of 10 ms). */
#define ME_DRIFT_HOLD_HOPS 100
#define ME_DRIFT_COOLDOWN_HOPS 10
/* A hop is quiet when its RMS is below this (≈ −45 dBFS). */
#define ME_DRIFT_QUIET_RMS 0.0056f

typedef struct {
    float avg_fill;
    int initialized;
    int high_hops;
    int low_hops;
    int cooldown;
} me_drift;

enum { ME_DRIFT_NONE = 0, ME_DRIFT_DROP = -1, ME_DRIFT_DUPLICATE = 1 };

void me_drift_reset(me_drift* d);

/*
 * Feeds the fill level seen before writing a hop and whether the hop is
 * quiet. Returns ME_DRIFT_NONE, ME_DRIFT_DROP or ME_DRIFT_DUPLICATE.
 */
int me_drift_update(me_drift* d, size_t fill, int quiet);

/*
 * Applies `action` to `buf` (length `n`, capacity at least n + 1) in place
 * and returns the new length. Drop removes the middle sample; duplicate
 * repeats it.
 */
size_t me_drift_apply(float* buf, size_t n, int action);

/* Whether `buf` (length n) is quiet enough for a correction. */
int me_drift_is_quiet(const float* buf, size_t n);

#endif /* ME_DRIFT_H */
