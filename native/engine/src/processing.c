#include <math.h>
#include <string.h>

#include "engine_internal.h"

/* Rolling-average smoothing for stats (~1 s at 100 hops/s). */
#define ME_STATS_ALPHA 0.01f

/* Max attenuation per strength preset, in dB. */
static const float kStrengthAttenuationDb[] = {12.0f, 24.0f, 100.0f};

float me_strength_attenuation_db(int32_t strength) {
    if (strength < ME_STRENGTH_LOW || strength > ME_STRENGTH_HIGH) strength = ME_STRENGTH_MEDIUM;
    return kStrengthAttenuationDb[strength];
}

void me_processing_reset(me_engine* engine) {
    int bypass = atomic_load_explicit(&engine->bypass, memory_order_relaxed);
    memset(engine->raw_delay, 0, sizeof engine->raw_delay);
    engine->applied_strength = -1;
    engine->seen_underruns = 0;
    me_agc_reset(&engine->agc_state);
    me_limiter_init(&engine->limiter, (float)ME_SAMPLE_RATE);
    /* One hop of fade: 10 ms, well within the 100 ms bypass target. */
    me_crossfade_init(&engine->xfade, bypass, ME_HOP);
    me_overload_reset(&engine->overload);
    atomic_store_explicit(&engine->overloaded, 0, memory_order_relaxed);
    me_levels_init(&engine->levels, ME_HOP_MS);
}

void me_process_hop(me_engine* engine, const float* in, float* out) {
    /* Settings are read once per hop. */
    int user_bypass = atomic_load_explicit(&engine->bypass, memory_order_relaxed);
    int agc_on = atomic_load_explicit(&engine->agc, memory_order_relaxed);
    int32_t strength = atomic_load_explicit(&engine->strength, memory_order_relaxed);
    int overloaded = engine->overload.active;

    if (strength != engine->applied_strength) {
        /* Only stores a float in libDF; takes effect on this hop. */
        mdf_set_atten_lim(engine->dfn, me_strength_attenuation_db(strength));
        engine->applied_strength = strength;
    }

    /* Raw audio delayed by one hop, so it lines up with DFN's output (the
     * low-latency model delays by exactly one hop). Bypass then neither
     * jumps in time nor comb-filters during the crossfade. */
    const float* raw = engine->raw_delay;

    if (overloaded) {
        /* Too busy: skip DFN entirely so the hop finishes in time. */
        memcpy(engine->proc_hop, raw, sizeof engine->proc_hop);
    } else {
        /* DFN keeps running while the user bypasses, so its state stays
         * continuous. A NaN means DFN failed on this hop: use raw audio. */
        float lsnr = mdf_process_frame(engine->dfn, in, engine->proc_hop);
        if (isnan(lsnr)) memcpy(engine->proc_hop, raw, sizeof engine->proc_hop);
        me_agc_process(&engine->agc_state, engine->proc_hop, ME_HOP, ME_HOP_MS, lsnr, agc_on);
    }

    me_crossfade_process(&engine->xfade, engine->proc_hop, raw, out, ME_HOP,
                         user_bypass || overloaded);
    me_limiter_process(&engine->limiter, out, ME_HOP);
    me_levels_update(&engine->levels, in, out, ME_HOP);

    memcpy(engine->raw_delay, in, sizeof engine->raw_delay);
}

static void process_one(me_engine* engine, int backlog) {
    /* An underrun while input was waiting means we fell behind. Without
     * waiting input it only means the microphone stopped. */
    uint32_t underruns = atomic_load_explicit(&engine->underruns, memory_order_relaxed);
    int starved = underruns != engine->seen_underruns && backlog;
    engine->seen_underruns = underruns;

    uint64_t t0 = me_now_us();
    me_process_hop(engine, engine->in_hop, engine->out_hop);
    float elapsed_ms = (float)(me_now_us() - t0) / 1000.0f;

    if (me_overload_update(&engine->overload, elapsed_ms, ME_HOP_MS, starved)) {
        atomic_fetch_add_explicit(&engine->overload_events, 1, memory_order_relaxed);
    }
    atomic_store_explicit(&engine->overloaded, engine->overload.active, memory_order_relaxed);

    size_t fill = me_ring_available(&engine->ring_out);
    size_t n = ME_HOP;
    if (fill > ME_OUTPUT_MAX_FILL) {
        /* The sink stalled; drop this hop to pull latency back down. */
        n = 0;
    } else {
        int action = me_drift_update(&engine->drift, fill,
                                     me_drift_is_quiet(engine->out_hop, ME_HOP));
        n = me_drift_apply(engine->out_hop, ME_HOP, action);
    }
    if (n > 0) me_ring_write(&engine->ring_out, engine->out_hop, n);

    atomic_fetch_add_explicit(&engine->frames_processed, 1, memory_order_relaxed);
    float avg = me_atomic_load_float(&engine->avg_process_ms_bits);
    me_atomic_store_float(&engine->avg_process_ms_bits, avg + ME_STATS_ALPHA * (elapsed_ms - avg));
    float out_fill = me_atomic_load_float(&engine->avg_out_fill_bits);
    me_atomic_store_float(&engine->avg_out_fill_bits,
                          out_fill + ME_STATS_ALPHA * ((float)fill - out_fill));
}

void me_processing_main(void* arg) {
    me_engine* engine = (me_engine*)arg;
    void* rt = me_thread_begin_realtime();
    mdf_rt_enter(engine->dfn);
    uint64_t last_hop_us = me_now_us();
    int meters_silent = 0;

    while (atomic_load_explicit(&engine->proc_run, memory_order_acquire)) {
        size_t avail = me_ring_available(&engine->ring_in);
        if (avail > ME_INPUT_MAX_FILL) {
            /* We fell behind (e.g. the machine stalled): keep the newest hop. */
            me_ring_skip(&engine->ring_in, avail - ME_HOP);
            avail = ME_HOP;
        }
        if (avail >= ME_HOP) {
            me_ring_read(&engine->ring_in, engine->in_hop, ME_HOP);
            process_one(engine, avail >= ME_BACKLOG_FRAMES);
            last_hop_us = me_now_us();
            meters_silent = 0;
        } else {
            if (!meters_silent && me_now_us() - last_hop_us > ME_LEVELS_IDLE_US) {
                /* No audio coming in (mic gone or switching): show silence. */
                me_levels_silence(&engine->levels);
                meters_silent = 1;
            }
            /* Wait for the next device period (2.5 ms) to arrive. */
            me_sleep_us(500);
        }
    }

    mdf_rt_leave();
    me_thread_end_realtime(rt);
}

void me_internal_rt_enter(me_engine* engine) { mdf_rt_enter(engine->dfn); }

void me_internal_rt_leave(void) { mdf_rt_leave(); }

size_t me_internal_rt_fallbacks(void) { return mdf_rt_fallbacks(); }

float me_internal_agc_gain_db(const me_engine* engine) { return engine->agc_state.gain_db; }

me_result me_internal_process_buffer(me_engine* engine, const float* in, float* out,
                                     size_t frames) {
    if (engine == NULL || (frames > 0 && (in == NULL || out == NULL))) return ME_ERR_INVALID_ARG;
    if (engine->running) return ME_ERR_STATE;
    float hop_in[ME_HOP];
    float hop_out[ME_HOP];
    for (size_t pos = 0; pos < frames; pos += ME_HOP) {
        size_t n = frames - pos < ME_HOP ? frames - pos : ME_HOP;
        memset(hop_in, 0, sizeof hop_in);
        memcpy(hop_in, in + pos, n * sizeof(float));
        me_process_hop(engine, hop_in, hop_out);
        memcpy(out + pos, hop_out, n * sizeof(float));
    }
    return ME_OK;
}
