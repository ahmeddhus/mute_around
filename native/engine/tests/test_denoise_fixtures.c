/*
 * Offline WAV-fixture test for noise suppression.
 *
 * Runs each fixture through the engine's offline processing path at Medium
 * and measures the noise floor over the fixture's noise-only range (see
 * fixtures/README.md). Passes when it drops by at least 20 dB.
 */
#include <stdio.h>
#include <stdlib.h>

#include "engine_internal.h"
#include "test_util.h"
#include "wav_util.h"

#define MIN_REDUCTION_DB 20.0

typedef struct {
    const char* file;
    /* Noise-only range, skipping the first 0.5 s while DFN converges. */
    double noise_start, noise_end;
    double speech_start, speech_end;
} fixture;

static const fixture kFixtures[] = {
    {"fan_speech.wav", 0.5, 2.0, 2.0, 8.0},
    {"keyboard.wav", 0.5, 2.0, 2.0, 8.0},
};

int main(void) {
    me_engine* engine = NULL;
    CHECK_EQ_INT(me_engine_create(NULL, &engine), ME_OK);
    if (engine == NULL) TEST_RESULT();
    me_set_strength(engine, ME_STRENGTH_MEDIUM);

    for (size_t f = 0; f < sizeof kFixtures / sizeof kFixtures[0]; f++) {
        const fixture* fx = &kFixtures[f];
        size_t frames = 0;
        float* in = me_wav_load(me_fixture_path(fx->file), &frames);
        CHECK(in != NULL);
        if (in == NULL) continue;
        float* out = (float*)malloc(frames * sizeof(float));
        CHECK_EQ_INT(me_internal_process_buffer(engine, in, out, frames), ME_OK);

        double noise_in = me_rms_db(in, frames, fx->noise_start, fx->noise_end);
        double noise_out = me_rms_db(out, frames, fx->noise_start, fx->noise_end);
        double speech_in = me_rms_db(in, frames, fx->speech_start, fx->speech_end);
        double speech_out = me_rms_db(out, frames, fx->speech_start, fx->speech_end);
        double reduction = noise_in - noise_out;
        printf("%-16s noise floor %6.1f → %6.1f dBFS (−%.1f dB); speech %6.1f → %6.1f dBFS\n",
               fx->file, noise_in, noise_out, reduction, speech_in, speech_out);
        CHECK(reduction >= MIN_REDUCTION_DB);

        free(in);
        free(out);
    }

    me_engine_destroy(engine);
    TEST_RESULT();
}
