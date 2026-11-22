/*
 * Overload state machine test with simulated
 * hop timings: enter after 3 hops above 80% of the period or on an output
 * underrun while input waits; leave after 5 s with every hop under 50%.
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

    TEST_RESULT();
}
