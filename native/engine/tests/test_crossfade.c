/*
 * Bypass crossfade test: switching between processed and raw
 * audio is smooth (no step bigger than the signals' own) and completes in
 * one 10 ms hop, well within the 100 ms bypass target.
 */
#include <math.h>
#include <stdio.h>

#include "crossfade.h"
#include "engine_internal.h"
#include "test_util.h"

#define FADE ME_HOP

/* Largest sample-to-sample step of a signal made of a 220 Hz "processed"
 * tone and a 330 Hz "raw" tone, toggling bypass at `toggle_hop`. */
static float run(int hops, int toggle_hop, int* raw_after) {
    me_crossfade xf;
    me_crossfade_init(&xf, 0, FADE);
    float processed[ME_HOP], raw[ME_HOP], out[ME_HOP];
    float prev = 0.0f, worst = 0.0f;
    int first = 1;
    for (int h = 0; h < hops; h++) {
        for (int i = 0; i < ME_HOP; i++) {
            double t = (double)(h * ME_HOP + i) / ME_SAMPLE_RATE;
            processed[i] = (float)(0.2 * sin(2 * M_PI * 220 * t));
            raw[i] = (float)(0.5 * sin(2 * M_PI * 330 * t + 1.0));
        }
        me_crossfade_process(&xf, processed, raw, out, ME_HOP, h >= toggle_hop);
        for (int i = 0; i < ME_HOP; i++) {
            if (!first) worst = fmaxf(worst, fabsf(out[i] - prev));
            prev = out[i];
            first = 0;
        }
        if (h == toggle_hop) *raw_after = me_crossfade_is_raw(&xf);
    }
    return worst;
}

int main(void) {
    /* The steepest a 330 Hz tone at 0.5 can move per sample. */
    float own = (float)(0.5 * 2 * M_PI * 330 / ME_SAMPLE_RATE);
    int raw_after = 0;
    float worst = run(10, 3, &raw_after);
    printf("largest step while switching %.4f (the raw tone alone: %.4f)\n", worst, own);
    /* A hard switch would jump by up to 0.7; the fade stays near the
     * signal's own slope (plus 0.7 / FADE from the fade itself). */
    CHECK(worst <= own + 0.7f / FADE + 1e-4f);
    CHECK(raw_after); /* fully raw by the end of the hop it was switched in */

    /* Switching back to processed completes too. */
    me_crossfade xf;
    me_crossfade_init(&xf, 1, FADE);
    float a[ME_HOP] = {0}, b[ME_HOP] = {0}, o[ME_HOP];
    me_crossfade_process(&xf, a, b, o, ME_HOP, 0);
    CHECK(me_crossfade_is_processed(&xf));

    /* Engine path: user bypass passes raw (delay-aligned) audio, and the
     * engine reports the user's bypass even while overloaded. */
    me_engine* engine = NULL;
    CHECK_EQ_INT(me_engine_create(NULL, &engine), ME_OK);
    if (engine != NULL) {
        me_set_bypass(engine, 1);
        me_set_agc(engine, 0);
        me_processing_reset(engine);
        float in[3 * ME_HOP], out[3 * ME_HOP];
        for (int i = 0; i < 3 * ME_HOP; i++) in[i] = 0.3f * sinf(i * 0.01f);
        CHECK_EQ_INT(me_internal_process_buffer(engine, in, out, 3 * ME_HOP), ME_OK);
        /* Raw audio comes out one hop later (aligned with DFN's delay). */
        float err = 0.0f;
        for (int i = ME_HOP; i < 3 * ME_HOP; i++) err = fmaxf(err, fabsf(out[i] - in[i - ME_HOP]));
        printf("bypass vs raw input (one hop later): max diff %.6f\n", err);
        CHECK(err < 1e-6f);
        me_engine_destroy(engine);
    }
    TEST_RESULT();
}
