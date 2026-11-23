/*
 * Offline WAV-fixture tests for automatic gain and the limiter.
 *
 * - near_far_speech.wav: the speech level of each near/far segment, once the
 *   AGC has settled, is within ±3 dB of the −18 dBFS target.
 * - loud_laugh.wav: no output sample above −1 dBFS.
 * - silence_noise.wav: noise alone never raises the gain.
 * - near_far_speech.wav: the noise left in the pauses between syllables is
 *   not boosted with the far voice: their level with auto gain on stays within
 *   ±3 dB of auto gain off.
 * - With auto gain off, the gain stays at 0 dB: speech keeps its level after
 *   noise suppression, while auto gain lifts far speech.
 * Unit checks on me_agc / me_limiter cover the gate and the ceiling directly.
 *
 * Each fixture run gets a fresh engine, so results don't depend on DFN
 * state left by an earlier file.
 */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "engine_internal.h"
#include "test_util.h"
#include "wav_util.h"

#define TOLERANCE_DB 3.0

/* Speech level of [start_s, end_s): the power mean of the 10 ms hops whose
 * *input* is clearly speech (well above the fixture's noise floor), so the
 * pauses between syllables don't count. */
static double speech_level_db(const float* in, const float* out, size_t frames, double start_s,
                              double end_s, double in_threshold_db) {
    size_t a = (size_t)(start_s * ME_SAMPLE_RATE), b = (size_t)(end_s * ME_SAMPLE_RATE);
    if (b > frames) b = frames;
    double sum = 0.0;
    size_t hops = 0;
    for (size_t pos = a; pos + ME_HOP <= b; pos += ME_HOP) {
        double pin = 0.0, pout = 0.0;
        for (size_t i = 0; i < ME_HOP; i++) {
            pin += (double)in[pos + i] * in[pos + i];
            pout += (double)out[pos + i] * out[pos + i];
        }
        if (10.0 * log10(pin / ME_HOP + 1e-12) < in_threshold_db) continue;
        sum += pout / ME_HOP;
        hops++;
    }
    return hops ? 10.0 * log10(sum / (double)hops + 1e-12) : -120.0;
}

/* AGC gain at the end of the last run(). */
static float g_last_gain_db;

static float* run(const char* name, int agc, size_t* frames, float** in_out) {
    float* in = me_wav_load(me_fixture_path(name), frames);
    CHECK(in != NULL);
    if (in == NULL) return NULL;
    me_engine* engine = NULL;
    CHECK_EQ_INT(me_engine_create(NULL, &engine), ME_OK);
    if (engine == NULL) {
        free(in);
        return NULL;
    }
    me_set_strength(engine, ME_STRENGTH_MEDIUM);
    me_set_agc(engine, (uint8_t)agc);
    me_processing_reset(engine);
    float* out = (float*)malloc(*frames * sizeof(float));
    CHECK_EQ_INT(me_internal_process_buffer(engine, in, out, *frames), ME_OK);
    g_last_gain_db = me_internal_agc_gain_db(engine);
    me_engine_destroy(engine);
    *in_out = in;
    return out;
}

static void test_near_far(void) {
    size_t frames = 0;
    float* in = NULL;
    float* out = run("near_far_speech.wav", 1, &frames, &in);
    if (out == NULL) return;
    /* Near from 1 s, switching every 1.5 s; measure the settled last 0.5 s. */
    for (int seg = 0; seg < 4; seg++) {
        double end = 1.0 + 1.5 * (seg + 1);
        double level_in = speech_level_db(in, in, frames, end - 0.5, end, -45.0);
        double level = speech_level_db(in, out, frames, end - 0.5, end, -45.0);
        printf("near_far %s %.1f–%.1f s: speech %6.1f → %6.1f dBFS (target %.0f)\n",
               seg % 2 ? "far " : "near", end - 0.5, end, level_in, level, ME_AGC_TARGET_DB);
        CHECK(fabs(level - ME_AGC_TARGET_DB) <= TOLERANCE_DB);
    }
    free(in);
    free(out);
}

static void test_loud_laugh(void) {
    size_t frames = 0;
    float* in = NULL;
    float* out = run("loud_laugh.wav", 1, &frames, &in);
    if (out == NULL) return;
    double peak_in = me_peak_db(in, frames, 0.0, 8.0);
    double peak_out = me_peak_db(out, frames, 0.0, 8.0);
    printf("loud_laugh peak %.2f → %.2f dBFS (ceiling %.0f)\n", peak_in, peak_out,
           ME_LIMITER_CEILING_DB);
    CHECK(peak_out <= ME_LIMITER_CEILING_DB);
    free(in);
    free(out);
}

static void test_silence_noise(void) {
    size_t frames = 0;
    float* in = NULL;
    float* out = run("silence_noise.wav", 1, &frames, &in);
    if (out == NULL) return;
    float gain = g_last_gain_db;
    printf("silence_noise AGC gain after 8 s: %.2f dB; output %.1f dBFS\n", gain,
           me_rms_db(out, frames, 0.5, 8.0));
    CHECK(gain <= 0.0f);
    free(in);
    free(out);
}

/* Median output level, in dBFS, of the hops in [start_s, end_s) whose input
 * is at most `in_max_db` (pauses: only the fan, no voice). `out` lags `in`
 * by one hop (DFN's delay). */
static double pause_median_db(const float* in, const float* out, size_t frames, double start_s,
                              double end_s, double in_max_db) {
    static double levels[2000];
    size_t count = 0;
    size_t a = (size_t)(start_s * ME_SAMPLE_RATE), b = (size_t)(end_s * ME_SAMPLE_RATE);
    for (size_t pos = a; pos + 2 * ME_HOP <= b && pos + 2 * ME_HOP <= frames &&
                         count < sizeof levels / sizeof levels[0];
         pos += ME_HOP) {
        double pin = 0.0, pout = 0.0;
        for (size_t i = 0; i < ME_HOP; i++) {
            pin += (double)in[pos + i] * in[pos + i];
            pout += (double)out[pos + ME_HOP + i] * out[pos + ME_HOP + i];
        }
        if (10.0 * log10(pin / ME_HOP + 1e-12) > in_max_db) continue;
        levels[count++] = 10.0 * log10(pout / ME_HOP + 1e-12);
    }
    if (count == 0) return -120.0;
    /* Insertion sort: a few hundred values. */
    for (size_t i = 1; i < count; i++) {
        double v = levels[i];
        size_t j = i;
        for (; j > 0 && levels[j - 1] > v; j--) levels[j] = levels[j - 1];
        levels[j] = v;
    }
    return levels[count / 2];
}

static void test_pause_noise_not_boosted(void) {
    size_t frames = 0;
    float *in_on = NULL, *in_off = NULL;
    float* on = run("near_far_speech.wav", 1, &frames, &in_on);
    float gain = g_last_gain_db;
    float* off = run("near_far_speech.wav", 0, &frames, &in_off);
    if (on == NULL || off == NULL) return;
    /* Room noise alone is −55 dBFS. The run ends in a far segment, where the
     * AGC boosts the voice by about 12 dB. */
    double pause_off = pause_median_db(in_off, off, frames, 5.5, 8.0, -50.0);
    double pause_on = pause_median_db(in_on, on, frames, 5.5, 8.0, -50.0);
    printf("near_far far pauses: AGC off %.1f, AGC on %.1f dBFS (speech gain %.1f dB)\n", pause_off,
           pause_on, gain);
    CHECK(gain > 6.0f); /* the voice really is boosted */
    CHECK(fabs(pause_on - pause_off) <= TOLERANCE_DB);
    free(in_on);
    free(in_off);
    free(on);
    free(off);
}

static void test_agc_off_keeps_level(void) {
    size_t frames = 0;
    float *in_on = NULL, *in_off = NULL;
    float* on = run("near_far_speech.wav", 1, &frames, &in_on);
    float* off = run("near_far_speech.wav", 0, &frames, &in_off);
    if (on == NULL || off == NULL) return;
    CHECK(fabsf(g_last_gain_db) < 1e-6f);
    /* Far segment: AGC on raises it, AGC off leaves it at the mic's level. */
    double far_in = speech_level_db(in_off, in_off, frames, 3.5, 4.0, -45.0);
    double far_off = speech_level_db(in_off, off, frames, 3.5, 4.0, -45.0);
    double far_on = speech_level_db(in_on, on, frames, 3.5, 4.0, -45.0);
    printf("far speech: in %.1f, AGC off %.1f, AGC on %.1f dBFS\n", far_in, far_off, far_on);
    CHECK(far_on > far_off + 6.0);
    free(in_on);
    free(in_off);
    free(on);
    free(off);
}

/* Direct checks on the building blocks. */
static void test_units(void) {
    float hop[ME_HOP];

    /* Short bursts above the gate (key clicks) don't move the gain. */
    me_agc agc;
    me_agc_reset(&agc);
    for (int i = 0; i < 50; i++) {
        for (int k = 0; k < ME_HOP; k++) hop[k] = 0.01f * sinf(k * 0.05f);
        me_agc_process(&agc, hop, ME_HOP, ME_HOP_MS, i % 4 == 0 ? 20.0f : 0.0f, 1);
    }
    CHECK(fabsf(agc.gain_db) < 1e-6f);

    /* Sustained quiet speech raises the gain, never beyond the maximum. */
    for (int i = 0; i < 500; i++) {
        for (int k = 0; k < ME_HOP; k++) hop[k] = 0.001f * sinf(k * 0.05f);
        me_agc_process(&agc, hop, ME_HOP, ME_HOP_MS, 20.0f, 1);
    }
    CHECK(agc.gain_db > 20.0f && agc.gain_db <= ME_AGC_MAX_GAIN_DB);

    /* Then silence: past the hangover the gain is held, not raised. */
    for (int i = 0; i < (int)(ME_AGC_HANGOVER_MS / ME_HOP_MS); i++) {
        memset(hop, 0, sizeof hop);
        me_agc_process(&agc, hop, ME_HOP, ME_HOP_MS, -10.0f, 1);
    }
    float held = agc.gain_db;
    for (int i = 0; i < 300; i++) {
        memset(hop, 0, sizeof hop);
        me_agc_process(&agc, hop, ME_HOP, ME_HOP_MS, -10.0f, 1);
    }
    CHECK(agc.gain_db <= held);

    /* Noise right after speech: the gain is still high, but it isn't applied
     * once the gate closes, so the noise keeps its level. */
    me_agc_reset(&agc);
    for (int i = 0; i < 500; i++) {
        for (int k = 0; k < ME_HOP; k++) hop[k] = 0.001f * sinf(k * 0.05f);
        me_agc_process(&agc, hop, ME_HOP, ME_HOP_MS, 20.0f, 1);
    }
    for (int i = 0; i < 30; i++) {
        for (int k = 0; k < ME_HOP; k++) hop[k] = 0.001f * sinf(k * 0.05f);
        me_agc_process(&agc, hop, ME_HOP, ME_HOP_MS, -10.0f, 1);
    }
    CHECK(agc.gain_db > 20.0f);
    CHECK(fabsf(hop[ME_HOP / 2]) < 0.001f * 1.5f); /* under +3.5 dB */

    /* Disabled: back to unity. */
    for (int k = 0; k < ME_HOP; k++) hop[k] = 0.1f;
    me_agc_process(&agc, hop, ME_HOP, ME_HOP_MS, 20.0f, 0);
    CHECK(fabsf(agc.gain_db) < 1e-6f);

    /* The limiter holds a full-scale square wave under the ceiling. */
    me_limiter lim;
    me_limiter_init(&lim, (float)ME_SAMPLE_RATE);
    float ceiling = powf(10.0f, ME_LIMITER_CEILING_DB / 20.0f);
    float worst = 0.0f;
    for (int i = 0; i < 20; i++) {
        for (int k = 0; k < ME_HOP; k++) hop[k] = (k / 24) % 2 ? 1.5f : -1.5f;
        me_limiter_process(&lim, hop, ME_HOP);
        for (int k = 0; k < ME_HOP; k++) worst = fmaxf(worst, fabsf(hop[k]));
    }
    CHECK(worst <= ceiling);
    /* Quiet audio passes untouched. */
    me_limiter_init(&lim, (float)ME_SAMPLE_RATE);
    for (int k = 0; k < ME_HOP; k++) hop[k] = 0.25f;
    me_limiter_process(&lim, hop, ME_HOP);
    CHECK(hop[ME_HOP - 1] == 0.25f);
}

int main(void) {
    test_units();
    test_near_far();
    test_loud_laugh();
    test_silence_noise();
    test_pause_noise_not_boosted();
    test_agc_off_keeps_level();
    TEST_RESULT();
}
