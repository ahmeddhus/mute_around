/*
 * Real-time allocation test.
 *
 * Runs the processing thread's per-hop work (DFN + AGC + limiter via
 * me_process_hop, plus the output ring write) on a thread entered on the DFN
 * pool, and asserts ZERO system-heap allocations per hop after a 100-hop
 * warm-up, and zero pool fallbacks.
 */
#include <math.h>
#include <stdio.h>

#include "alloc_counter.h"
#include "engine_internal.h"
#include "test_util.h"

#define WARMUP_HOPS 100
#define MEASURED_HOPS 1000

/* Speech-like test signal: syllables of harmonics over noise. */
static void fill_hop(float* hop, int index, unsigned* seed) {
    for (int i = 0; i < ME_HOP; i++) {
        int t = index * ME_HOP + i;
        float env = (t / 9600) % 2 ? 1.0f : 0.1f;
        *seed = *seed * 1664525u + 1013904223u;
        float noise = 0.02f * ((float)(*seed >> 9) / 8388608.0f - 1.0f);
        hop[i] = env * (0.1f * sinf(t * 0.018f) + 0.05f * sinf(t * 0.041f)) + noise;
    }
}

int main(void) {
    me_engine* engine = NULL;
    CHECK_EQ_INT(me_engine_create(NULL, &engine), ME_OK);
    if (engine == NULL) TEST_RESULT();

    float in[ME_HOP], out[ME_HOP];
    unsigned seed = 7;
    long worst = 0, total = 0;

    me_internal_rt_enter(engine);
    me_alloc_counter_install();
    for (int hop = 0; hop < WARMUP_HOPS + MEASURED_HOPS; hop++) {
        /* Exercise every setting the processing thread reads. */
        me_set_bypass(engine, (uint8_t)(hop % 50 == 0));
        me_set_agc(engine, (uint8_t)(hop % 70 != 0));
        me_set_strength(engine, (me_strength)(hop % 3));
        fill_hop(in, hop, &seed);

        long before = me_alloc_counter_get();
        me_process_hop(engine, in, out);
        if (me_ring_space(&engine->ring_out) < ME_HOP) me_ring_skip(&engine->ring_out, ME_HOP);
        me_ring_write(&engine->ring_out, out, ME_HOP);
        long n = me_alloc_counter_get() - before;

        if (hop >= WARMUP_HOPS) {
            total += n;
            if (n > worst) worst = n;
        }
    }
    me_internal_rt_leave();

    printf("system-heap allocations after warm-up: total %ld, worst hop %ld; pool fallbacks %zu\n",
           total, worst, me_internal_rt_fallbacks());
    CHECK_EQ_INT(total, 0);
    CHECK_EQ_INT(me_internal_rt_fallbacks(), 0);

    me_engine_destroy(engine);
    TEST_RESULT();
}
