#include "overload.h"

void me_overload_reset(me_overload* ov) {
    ov->active = 0;
    ov->slow_hops = 0;
    ov->calm_ms = 0.0f;
    ov->exit_ms = ME_OVERLOAD_EXIT_MS;
    ov->since_exit_ms = -1.0f;
}

int me_overload_update(me_overload* ov, float process_ms, float period_ms, int starved) {
    if (!ov->active) {
        if (ov->since_exit_ms >= 0.0f) {
            ov->since_exit_ms += period_ms;
            if (ov->since_exit_ms >= ME_OVERLOAD_RELAPSE_MS) {
                /* Stayed out long enough: the load really went away. */
                ov->exit_ms = ME_OVERLOAD_EXIT_MS;
                ov->since_exit_ms = -1.0f;
            }
        }
        ov->slow_hops = process_ms > ME_OVERLOAD_ENTER_RATIO * period_ms ? ov->slow_hops + 1 : 0;
        if (starved || ov->slow_hops >= ME_OVERLOAD_ENTER_HOPS) {
            if (ov->since_exit_ms >= 0.0f) {
                /* Back in soon after leaving: wait longer next time. */
                ov->exit_ms *= 2.0f;
                if (ov->exit_ms > ME_OVERLOAD_EXIT_MAX_MS) ov->exit_ms = ME_OVERLOAD_EXIT_MAX_MS;
            }
            ov->active = 1;
            ov->slow_hops = 0;
            ov->calm_ms = 0.0f;
            ov->since_exit_ms = -1.0f;
            return 1;
        }
        return 0;
    }
    if (starved || process_ms >= ME_OVERLOAD_EXIT_RATIO * period_ms) {
        ov->calm_ms = 0.0f;
    } else {
        ov->calm_ms += period_ms;
        if (ov->calm_ms >= ov->exit_ms) {
            ov->active = 0;
            ov->calm_ms = 0.0f;
            ov->since_exit_ms = 0.0f;
        }
    }
    return 0;
}
