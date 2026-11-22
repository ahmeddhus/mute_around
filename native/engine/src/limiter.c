#include "limiter.h"

#include <math.h>

void me_limiter_init(me_limiter* lim, float sample_rate) {
    lim->env = 0.0f;
    lim->release = expf(-1.0f / (ME_LIMITER_RELEASE_MS * 0.001f * sample_rate));
    lim->ceiling = powf(10.0f, ME_LIMITER_CEILING_DB / 20.0f);
}

void me_limiter_process(me_limiter* lim, float* buf, size_t n) {
    for (size_t i = 0; i < n; i++) {
        float a = fabsf(buf[i]);
        /* Instant attack: the envelope is never below the current sample,
         * so the gain below always brings it under the ceiling. */
        lim->env = a > lim->env ? a : lim->env * lim->release;
        if (lim->env > lim->ceiling) {
            buf[i] *= lim->ceiling / lim->env;
            /* Float rounding can leave it a hair above; clamp exactly. */
            if (buf[i] > lim->ceiling) buf[i] = lim->ceiling;
            if (buf[i] < -lim->ceiling) buf[i] = -lim->ceiling;
        }
    }
}
