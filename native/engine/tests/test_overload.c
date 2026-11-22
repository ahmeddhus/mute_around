/*
 * Overload state machine test with simulated
 * hop timings: enter after 3 hops above 80% of the period or on an output
 * underrun while input waits; leave after 5 s with every hop under 50%,
 * backing off to 80 s when the load comes straight back.
 */
#include <stdio.h>

#include "overload.h"
#include "test_util.h"

#define PERIOD 10.0f

int main(void) {
    me_overload ov;

    /* Two slow hops are tolerated; the third enters (within 30 ms). */
    me_overload_reset(&ov);
    CHECK_EQ_INT(me_overload_update(&ov, 9.0f, PERIOD, 0), 0);
    CHECK_EQ_INT(me_overload_update(&ov, 9.0f, PERIOD, 0), 0);
    CHECK_EQ_INT(ov.active, 0);
    CHECK_EQ_INT(me_overload_update(&ov, 9.0f, PERIOD, 0), 1);
    CHECK_EQ_INT(ov.active, 1);

    /* Slow hops must be consecutive. */
    me_overload_reset(&ov);
    for (int i = 0; i < 100; i++) me_overload_update(&ov, i % 3 == 2 ? 2.0f : 9.0f, PERIOD, 0);
    CHECK_EQ_INT(ov.active, 0);

    /* Exactly 80% is not slow. */
    me_overload_reset(&ov);
    for (int i = 0; i < 10; i++) me_overload_update(&ov, 8.0f, PERIOD, 0);
    CHECK_EQ_INT(ov.active, 0);

    /* An underrun while input waits enters at once. */
    me_overload_reset(&ov);
    CHECK_EQ_INT(me_overload_update(&ov, 1.0f, PERIOD, 1), 1);
    CHECK_EQ_INT(ov.active, 1);

    /* Leaves after 5 s of calm hops (500 × 10 ms), not before. */
    for (int i = 0; i < 499; i++) me_overload_update(&ov, 1.0f, PERIOD, 0);
    CHECK_EQ_INT(ov.active, 1);
    me_overload_update(&ov, 1.0f, PERIOD, 0);
    CHECK_EQ_INT(ov.active, 0);

    /* A hop at or above 50% (or an underrun) restarts the 5 s. */
    me_overload_reset(&ov);
    me_overload_update(&ov, 1.0f, PERIOD, 1);
    for (int i = 0; i < 400; i++) me_overload_update(&ov, 1.0f, PERIOD, 0);
    me_overload_update(&ov, 5.0f, PERIOD, 0);
    for (int i = 0; i < 499; i++) me_overload_update(&ov, 1.0f, PERIOD, 0);
    CHECK_EQ_INT(ov.active, 1);
    me_overload_update(&ov, 1.0f, PERIOD, 0);
    CHECK_EQ_INT(ov.active, 0);

    /* Entering is reported once, not on every overloaded hop. */
    me_overload_reset(&ov);
    int entries = 0;
    for (int i = 0; i < 50; i++) entries += me_overload_update(&ov, 9.5f, PERIOD, 0);
    CHECK_EQ_INT(entries, 1);

    /* Sustained load: the engine skips DFN while overloaded, so those hops
     * look calm (1 ms); with DFN back on they're slow (9.5 ms). Without
     * backoff this cycled every 5 s (120 re-entries in 10 min). The calm
     * window doubles on each quick relapse, 5 → 10 → 20 → 40 → 80 s. */
    me_overload_reset(&ov);
    entries = 0;
    int longest_out = 0;
    int out_hops = 0;
    for (int i = 0; i < 60000; i++) { /* 10 min of 10 ms hops */
        float ms = ov.active ? 1.0f : 9.5f;
        entries += me_overload_update(&ov, ms, PERIOD, 0);
        out_hops = ov.active ? 0 : out_hops + 1;
        if (out_hops > longest_out) longest_out = out_hops;
    }
    /* First entry, 4 relapses to reach 80 s (75 s), then one per ~80 s. */
    CHECK(entries >= 10 && entries <= 12);
    CHECK_EQ_INT(longest_out, ME_OVERLOAD_ENTER_HOPS);
    CHECK(ov.exit_ms == ME_OVERLOAD_EXIT_MAX_MS);

    /* After a relapse the next calm window is 10 s, not 5 s. */
    me_overload_reset(&ov);
    me_overload_update(&ov, 1.0f, PERIOD, 1);
    for (int i = 0; i < 500; i++) me_overload_update(&ov, 1.0f, PERIOD, 0);
    CHECK_EQ_INT(ov.active, 0);
    CHECK_EQ_INT(me_overload_update(&ov, 1.0f, PERIOD, 1), 1);
    for (int i = 0; i < 999; i++) me_overload_update(&ov, 1.0f, PERIOD, 0);
    CHECK_EQ_INT(ov.active, 1);
    me_overload_update(&ov, 1.0f, PERIOD, 0);
    CHECK_EQ_INT(ov.active, 0);

    /* Staying out for 10 s means the load went away: back to 5 s. */
    for (int i = 0; i < 1000; i++) me_overload_update(&ov, 1.0f, PERIOD, 0);
    CHECK(ov.exit_ms == ME_OVERLOAD_EXIT_MS);
    me_overload_update(&ov, 1.0f, PERIOD, 1);
    for (int i = 0; i < 500; i++) me_overload_update(&ov, 1.0f, PERIOD, 0);
    CHECK_EQ_INT(ov.active, 0);

    /* The window never grows past its cap. */
    me_overload_reset(&ov);
    for (int round = 0; round < 20; round++) {
        me_overload_update(&ov, 1.0f, PERIOD, 1);
        while (ov.active) me_overload_update(&ov, 1.0f, PERIOD, 0);
    }
    CHECK(ov.exit_ms == ME_OVERLOAD_EXIT_MAX_MS);

    TEST_RESULT();
}
