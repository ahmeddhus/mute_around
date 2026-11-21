/*
 * Output limiter: keeps every sample at or below
 * ME_LIMITER_CEILING_DB with an instant attack and a 50 ms release, so loud
 * speech or a laugh never clips.
 *
 * Real-time safe: no allocation, no locks.
 */
#ifndef ME_LIMITER_H
#define ME_LIMITER_H

#include <stddef.h>

#define ME_LIMITER_CEILING_DB (-1.0f)
#define ME_LIMITER_RELEASE_MS 50.0f

typedef struct {
    float env;     /* peak envelope (linear) */
    float release; /* per-sample envelope decay */
    float ceiling; /* linear ceiling */
} me_limiter;

void me_limiter_init(me_limiter* lim, float sample_rate);

/* Limits `buf` in place. */
void me_limiter_process(me_limiter* lim, float* buf, size_t n);

#endif /* ME_LIMITER_H */
