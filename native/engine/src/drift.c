#include "drift.h"

#include <math.h>
#include <string.h>

/* Smoothing for the fill average: ~50-hop (0.5 s) time constant. */
#define ME_DRIFT_ALPHA 0.02f

void me_drift_reset(me_drift* d) { memset(d, 0, sizeof *d); }

int me_drift_update(me_drift* d, size_t fill, int quiet) {
    float f = (float)fill;
    if (!d->initialized) {
        d->avg_fill = f;
        d->initialized = 1;
    } else {
        d->avg_fill += ME_DRIFT_ALPHA * (f - d->avg_fill);
    }

    d->high_hops = d->avg_fill > (float)ME_DRIFT_HIGH ? d->high_hops + 1 : 0;
    d->low_hops = d->avg_fill < (float)ME_DRIFT_LOW ? d->low_hops + 1 : 0;
    if (d->cooldown > 0) {
        d->cooldown--;
        return ME_DRIFT_NONE;
    }
    if (!quiet) return ME_DRIFT_NONE;

    if (d->high_hops >= ME_DRIFT_HOLD_HOPS) {
        d->cooldown = ME_DRIFT_COOLDOWN_HOPS;
        d->avg_fill -= 1.0f;
        return ME_DRIFT_DROP;
    }
    if (d->low_hops >= ME_DRIFT_HOLD_HOPS) {
        d->cooldown = ME_DRIFT_COOLDOWN_HOPS;
        d->avg_fill += 1.0f;
        return ME_DRIFT_DUPLICATE;
    }
    return ME_DRIFT_NONE;
}

size_t me_drift_apply(float* buf, size_t n, int action) {
    if (n < 2) return n;
    size_t mid = n / 2;
    switch (action) {
        case ME_DRIFT_DROP:
            memmove(buf + mid, buf + mid + 1, (n - mid - 1) * sizeof(float));
            return n - 1;
        case ME_DRIFT_DUPLICATE:
            memmove(buf + mid + 1, buf + mid, (n - mid) * sizeof(float));
            return n + 1;
        default:
            return n;
    }
}

int me_drift_is_quiet(const float* buf, size_t n) {
    float sum = 0.0f;
    for (size_t i = 0; i < n; i++) sum += buf[i] * buf[i];
    return n > 0 && sqrtf(sum / (float)n) < ME_DRIFT_QUIET_RMS;
}
