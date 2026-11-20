#include <string.h>

#include "drift.h"
#include "test_util.h"

static void test_stays_quiet_on_target(void) {
    me_drift d;
    me_drift_reset(&d);
    for (int i = 0; i < 1000; i++) CHECK_EQ_INT(me_drift_update(&d, ME_DRIFT_TARGET, 1), ME_DRIFT_NONE);
}

static void test_drops_when_too_full_for_one_second(void) {
    me_drift d;
    me_drift_reset(&d);
    int first = -1;
    for (int i = 0; i < 300; i++) {
        int a = me_drift_update(&d, ME_DRIFT_HIGH + 200, 1);
        if (a != ME_DRIFT_NONE && first < 0) {
            CHECK_EQ_INT(a, ME_DRIFT_DROP);
            first = i;
        }
    }
    /* Not before the 1 s hold, and soon after it. */
    CHECK(first >= ME_DRIFT_HOLD_HOPS - 1);
    CHECK(first < ME_DRIFT_HOLD_HOPS + 50);
}

static void test_duplicates_when_too_empty(void) {
    me_drift d;
    me_drift_reset(&d);
    int dups = 0;
    for (int i = 0; i < 400; i++) dups += me_drift_update(&d, 0, 1) == ME_DRIFT_DUPLICATE;
    CHECK(dups > 0);
    /* Cooldown: at most one correction per ME_DRIFT_COOLDOWN_HOPS + 1 hops. */
    CHECK(dups <= 400 / (ME_DRIFT_COOLDOWN_HOPS + 1) + 1);
}

static void test_waits_for_a_quiet_hop(void) {
    me_drift d;
    me_drift_reset(&d);
    for (int i = 0; i < 300; i++) CHECK_EQ_INT(me_drift_update(&d, 2000, 0), ME_DRIFT_NONE);
    CHECK_EQ_INT(me_drift_update(&d, 2000, 1), ME_DRIFT_DROP);
}

static void test_apply_and_quiet(void) {
    float buf[6] = {1, 2, 3, 4, 5, 0};
    CHECK_EQ_INT(me_drift_apply(buf, 5, ME_DRIFT_DROP), 4);
    CHECK(buf[0] == 1 && buf[1] == 2 && buf[2] == 4 && buf[3] == 5);

    float dup[6] = {1, 2, 3, 4, 5, 0};
    CHECK_EQ_INT(me_drift_apply(dup, 5, ME_DRIFT_DUPLICATE), 6);
    CHECK(dup[2] == 3 && dup[3] == 3 && dup[5] == 5);

    CHECK_EQ_INT(me_drift_apply(dup, 5, ME_DRIFT_NONE), 5);

    float quiet[480], loud[480];
    for (int i = 0; i < 480; i++) {
        quiet[i] = (i % 2 ? 1 : -1) * 0.001f;
        loud[i] = (i % 2 ? 1 : -1) * 0.1f;
    }
    CHECK(me_drift_is_quiet(quiet, 480));
    CHECK(!me_drift_is_quiet(loud, 480));
}

int main(void) {
    test_stays_quiet_on_target();
    test_drops_when_too_full_for_one_second();
    test_duplicates_when_too_empty();
    test_waits_for_a_quiet_hop();
    test_apply_and_quiet();
    TEST_RESULT();
}
