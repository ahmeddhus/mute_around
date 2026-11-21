#include "levels.h"

#include <math.h>
#include <string.h>

static void store(_Atomic uint32_t* slot, float v) {
    uint32_t bits;
    memcpy(&bits, &v, sizeof bits);
    atomic_store_explicit(slot, bits, memory_order_relaxed);
}

static float load(_Atomic uint32_t* slot) {
    uint32_t bits = atomic_load_explicit(slot, memory_order_relaxed);
    float v;
    memcpy(&v, &bits, sizeof v);
    return v;
}

static float to_db(float linear, int power) {
    if (linear <= 0.0f) return ME_LEVEL_FLOOR_DB;
    float db = power ? 10.0f * log10f(linear) : 20.0f * log10f(linear);
    if (db < ME_LEVEL_FLOOR_DB) return ME_LEVEL_FLOOR_DB;
    return db > 0.0f ? 0.0f : db;
}

static void measure(me_meter* m, const float* x, size_t n, float decay, float alpha) {
    float peak = 0.0f;
    double sum = 0.0;
    for (size_t i = 0; i < n; i++) {
        float a = fabsf(x[i]);
        if (a > peak) peak = a;
        sum += (double)x[i] * x[i];
    }
    float power = n > 0 ? (float)(sum / (double)n) : 0.0f;
    m->peak = peak > m->peak * decay ? peak : m->peak * decay;
    m->power += alpha * (power - m->power);
}

void me_levels_init(me_levels_state* lv, float hop_ms) {
    memset(&lv->in, 0, sizeof lv->in);
    memset(&lv->out, 0, sizeof lv->out);
    lv->peak_decay = expf(-hop_ms / ME_LEVEL_PEAK_DECAY_MS);
    lv->rms_alpha = 1.0f - expf(-hop_ms / ME_LEVEL_RMS_MS);
    me_levels_silence(lv);
}

void me_levels_update(me_levels_state* lv, const float* in, const float* out, size_t n) {
    measure(&lv->in, in, n, lv->peak_decay, lv->rms_alpha);
    measure(&lv->out, out, n, lv->peak_decay, lv->rms_alpha);
    store(&lv->in_peak_db, to_db(lv->in.peak, 0));
    store(&lv->in_rms_db, to_db(lv->in.power, 1));
    store(&lv->out_peak_db, to_db(lv->out.peak, 0));
    store(&lv->out_rms_db, to_db(lv->out.power, 1));
}

void me_levels_silence(me_levels_state* lv) {
    lv->in.peak = lv->in.power = lv->out.peak = lv->out.power = 0.0f;
    store(&lv->in_peak_db, ME_LEVEL_FLOOR_DB);
    store(&lv->in_rms_db, ME_LEVEL_FLOOR_DB);
    store(&lv->out_peak_db, ME_LEVEL_FLOOR_DB);
    store(&lv->out_rms_db, ME_LEVEL_FLOOR_DB);
}

void me_levels_read(me_levels_state* lv, me_levels* out) {
    out->input_peak_db = load(&lv->in_peak_db);
    out->input_rms_db = load(&lv->in_rms_db);
    out->output_peak_db = load(&lv->out_peak_db);
    out->output_rms_db = load(&lv->out_rms_db);
}
