#include <math.h>
#include <string.h>

#include "engine_internal.h"

/* Rolling-average smoothing for stats (~1 s at 100 hops/s). */
#define ME_STATS_ALPHA 0.01f

void me_process_hop(me_engine* engine, const float* in, float* out) {
    float lsnr = mdf_process_frame(engine->dfn, in, out);
    int bypass = atomic_load_explicit(&engine->bypass, memory_order_relaxed);
    /* DFN keeps running while bypassed so its state stays continuous. A NaN
     * means DFN failed on this hop; pass the raw audio rather than nothing. */
    if (bypass || isnan(lsnr)) memcpy(out, in, ME_HOP * sizeof(float));
    /* AGC + limiter and the bypass crossfade go here. */
}

static void process_one(me_engine* engine) {
    uint64_t t0 = me_now_us();
    me_process_hop(engine, engine->in_hop, engine->out_hop);
    float elapsed_ms = (float)(me_now_us() - t0) / 1000.0f;

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

    while (atomic_load_explicit(&engine->proc_run, memory_order_acquire)) {
        size_t avail = me_ring_available(&engine->ring_in);
        if (avail > ME_INPUT_MAX_FILL) {
            /* We fell behind (e.g. the machine stalled): keep the newest hop. */
            me_ring_skip(&engine->ring_in, avail - ME_HOP);
            avail = ME_HOP;
        }
        if (avail >= ME_HOP) {
            me_ring_read(&engine->ring_in, engine->in_hop, ME_HOP);
            process_one(engine);
        } else {
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
