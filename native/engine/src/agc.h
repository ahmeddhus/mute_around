/*
 * Speech-gated automatic gain control.
 *
 * Runs after noise suppression, once per 10 ms hop. It measures the level of
 * speech only (hops where DeepFilterNet's local SNR is above
 * ME_AGC_GATE_SNR_DB for at least ME_AGC_SPEECH_HOPS in a row), averaged
 * in dB over ME_AGC_LEVEL_MS, and moves the gain toward the one that brings that
 * level to ME_AGC_TARGET_DB: down with a 50 ms time constant, up with
 * 400 ms. Within ME_AGC_HANGOVER_MS of speech the gain keeps converging (the
 * gaps between words); in longer silence it is held, never raised, so
 * leftover noise isn't pumped up.
 *
 * A boost (positive gain) is applied only while someone is speaking: it is
 * scaled by a speech presence that follows the per-hop SNR gate, rising in
 * ME_AGC_PRESENCE_ATTACK_MS and falling in ME_AGC_PRESENCE_RELEASE_MS. The
 * noise DeepFilterNet leaves in pauses and at word ends is therefore not
 * lifted with the voice. A cut (negative gain) always applies in full. Gain
 * changes are ramped across the hop, so they never click.
 *
 * Real-time safe: no allocation, no locks, O(n) per hop.
 */
#ifndef ME_AGC_H
#define ME_AGC_H

#include <stddef.h>

#define ME_AGC_TARGET_DB (-18.0f)
#define ME_AGC_GATE_SNR_DB 5.0f
#define ME_AGC_ATTACK_MS 50.0f   /* gain going down (speech got louder) */
#define ME_AGC_RELEASE_MS 400.0f /* gain going up (speech got quieter) */
/* The speech level (in dB, so loud syllables don't dominate) is averaged
 * over this long, speech hops only. */
#define ME_AGC_LEVEL_MS 100.0f
/* After speech stops, the gain keeps moving toward the speech-derived
 * target for this long (the gaps between words); after that it is held. */
#define ME_AGC_HANGOVER_MS 300.0f
#define ME_AGC_MIN_GAIN_DB (-10.0f)
#define ME_AGC_MAX_GAIN_DB 24.0f
/* Speech must pass the gate for this many hops in a row (50 ms): shorter
 * bursts, such as key clicks, are not speech and don't move the gain. */
#define ME_AGC_SPEECH_HOPS 5
/* Hops quieter than this are never treated as speech, whatever the SNR. */
#define ME_AGC_MIN_SPEECH_DB (-70.0f)
/* Speech presence time constants: the boost comes in fast enough to keep
 * word onsets, and fades slowly enough not to chop syllables. */
#define ME_AGC_PRESENCE_ATTACK_MS 10.0f
#define ME_AGC_PRESENCE_RELEASE_MS 40.0f

typedef struct {
    float level_db;        /* averaged speech level (before gain) */
    float gain_db;         /* tracked speech gain at the end of the last hop */
    float applied_db;      /* gain applied at the end of the last hop (boost
                              scaled by presence) */
    float presence;        /* smoothed speech presence, 0…1 */
    int has_level;         /* a speech hop has been seen */
    int gated_hops;        /* consecutive hops above the gate */
    float since_speech_ms; /* time since the last speech hop */
} me_agc;

/* Unity gain, no level yet. */
void me_agc_reset(me_agc* agc);

/*
 * Applies the AGC to `buf` (n samples, one hop of `hop_ms`) in place.
 * `lsnr_db` is DFN's local SNR for this hop. With `enabled` false the gain
 * ramps back to 0 dB, and the speech level keeps being tracked so turning
 * it back on starts from a good estimate.
 */
void me_agc_process(me_agc* agc, float* buf, size_t n, float hop_ms, float lsnr_db, int enabled);

#endif /* ME_AGC_H */
