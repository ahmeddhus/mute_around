#include "crossfade.h"

void me_crossfade_init(me_crossfade* xf, int raw, size_t fade_samples) {
    xf->mix = raw ? 1.0f : 0.0f;
    xf->step = fade_samples > 0 ? 1.0f / (float)fade_samples : 1.0f;
}

void me_crossfade_process(me_crossfade* xf, const float* processed, const float* raw, float* out,
                          size_t n, int to_raw) {
    float target = to_raw ? 1.0f : 0.0f;
    for (size_t i = 0; i < n; i++) {
        if (xf->mix < target) {
            xf->mix += xf->step;
            if (xf->mix > target) xf->mix = target;
        } else if (xf->mix > target) {
            xf->mix -= xf->step;
            if (xf->mix < target) xf->mix = target;
        }
        float p = processed[i];
        out[i] = p + xf->mix * (raw[i] - p);
    }
}

int me_crossfade_is_raw(const me_crossfade* xf) { return xf->mix >= 1.0f; }

int me_crossfade_is_processed(const me_crossfade* xf) { return xf->mix <= 0.0f; }
