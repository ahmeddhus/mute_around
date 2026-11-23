#include "agc.h"

#include <math.h>

void me_agc_reset(me_agc* agc) {
    agc->level_db = ME_AGC_TARGET_DB;
    agc->gain_db = 0.0f;
    agc->applied_db = 0.0f;
    agc->presence = 0.0f;
    agc->has_level = 0;
    agc->gated_hops = 0;
    agc->since_speech_ms = ME_AGC_HANGOVER_MS;
}

static float power_of(const float* buf, size_t n) {
    double sum = 0.0;
    for (size_t i = 0; i < n; i++) sum += (double)buf[i] * buf[i];
    return n > 0 ? (float)(sum / (double)n) : 0.0f;
}

static float to_db(float power) { return power > 1e-12f ? 10.0f * log10f(power) : -120.0f; }

static float clampf(float x, float lo, float hi) { return x < lo ? lo : (x > hi ? hi : x); }

void me_agc_process(me_agc* agc, float* buf, size_t n, float hop_ms, float lsnr_db, int enabled) {
    float power = power_of(buf, n);
    int gated =
        !isnan(lsnr_db) && lsnr_db > ME_AGC_GATE_SNR_DB && to_db(power) > ME_AGC_MIN_SPEECH_DB;
    agc->gated_hops = gated ? agc->gated_hops + 1 : 0;
    int speech = agc->gated_hops >= ME_AGC_SPEECH_HOPS;
    agc->since_speech_ms = speech ? 0.0f : agc->since_speech_ms + hop_ms;
    int near_speech = agc->since_speech_ms < ME_AGC_HANGOVER_MS;

    float presence_target = gated ? 1.0f : 0.0f;
    float presence_tau =
        presence_target > agc->presence ? ME_AGC_PRESENCE_ATTACK_MS : ME_AGC_PRESENCE_RELEASE_MS;
    agc->presence += (1.0f - expf(-hop_ms / presence_tau)) * (presence_target - agc->presence);

    if (speech) {
        float level = to_db(power);
        if (!agc->has_level) {
            agc->level_db = level;
            agc->has_level = 1;
        } else {
            agc->level_db += (1.0f - expf(-hop_ms / ME_AGC_LEVEL_MS)) * (level - agc->level_db);
        }
    }

    float target_gain = 0.0f;
    if (enabled && agc->has_level) {
        float wanted =
            clampf(ME_AGC_TARGET_DB - agc->level_db, ME_AGC_MIN_GAIN_DB, ME_AGC_MAX_GAIN_DB);
        float tau = wanted < agc->gain_db ? ME_AGC_ATTACK_MS : ME_AGC_RELEASE_MS;
        float moved = agc->gain_db + (1.0f - expf(-hop_ms / tau)) * (wanted - agc->gain_db);
        /* Longer silence: hold the gain, or let it fall, never raise it. */
        target_gain = near_speech ? moved : fminf(moved, agc->gain_db);
    }

    /* Boost speech only, so pause noise stays where suppression left it. */
    float applied = target_gain > 0.0f ? target_gain * agc->presence : target_gain;

    /* Ramp linearly (in amplitude) from the previous gain to the new one. */
    float g0 = powf(10.0f, agc->applied_db / 20.0f);
    float g1 = powf(10.0f, applied / 20.0f);
    if (n > 0) {
        float step = (g1 - g0) / (float)n;
        for (size_t i = 0; i < n; i++) buf[i] *= g0 + step * (float)(i + 1);
    }
    agc->gain_db = target_gain;
    agc->applied_db = applied;
}
