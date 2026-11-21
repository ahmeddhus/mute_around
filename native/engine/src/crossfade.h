/*
 * Bypass crossfade: switches between the processed and the raw
 * signal over 10 ms, so toggling bypass (by the user or the overload
 * detector) never clicks and takes effect well within 100 ms.
 *
 * Real-time safe: no allocation, no locks.
 */
#ifndef ME_CROSSFADE_H
#define ME_CROSSFADE_H

#include <stddef.h>

typedef struct {
    float mix;  /* 0 = processed, 1 = raw */
    float step; /* mix change per sample */
} me_crossfade;

/* Starts fully on `raw` (1) or processed (0); fades over `fade_samples`. */
void me_crossfade_init(me_crossfade* xf, int raw, size_t fade_samples);

/*
 * Writes the mix of `processed` and `raw` into `out` (may alias either),
 * moving toward raw when `to_raw` is set and toward processed otherwise.
 */
void me_crossfade_process(me_crossfade* xf, const float* processed, const float* raw, float* out,
                          size_t n, int to_raw);

/* Whether the output is entirely raw / entirely processed right now. */
int me_crossfade_is_raw(const me_crossfade* xf);
int me_crossfade_is_processed(const me_crossfade* xf);

#endif /* ME_CROSSFADE_H */
