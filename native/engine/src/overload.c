#include "overload.h"

void me_overload_reset(me_overload* ov) {
    ov->active = 0;
    ov->slow_hops = 0;
    ov->calm_ms = 0.0f;
}

int me_overload_update(me_overload* ov, float process_ms, float period_ms, int starved) {
    if (!ov->active) {
        ov->slow_hops = process_ms > ME_OVERLOAD_ENTER_RATIO * period_ms ? ov->slow_hops + 1 : 0;
        if (starved || ov->slow_hops >= ME_OVERLOAD_ENTER_HOPS) {
            ov->active = 1;
            ov->slow_hops = 0;
            ov->calm_ms = 0.0f;
            return 1;
        }
        return 0;
    }
    if (starved || process_ms >= ME_OVERLOAD_EXIT_RATIO * period_ms) {
        ov->calm_ms = 0.0f;
    } else {
        ov->calm_ms += period_ms;
        if (ov->calm_ms >= ME_OVERLOAD_EXIT_MS) {
            ov->active = 0;
            ov->calm_ms = 0.0f;
        }
    }
    return 0;
}
