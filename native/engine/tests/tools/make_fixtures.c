/*
 * Generates the synthetic WAV fixtures in native/engine/tests/fixtures/.
 *
 * Everything is synthesized from a fixed seed, so the files are reproducible
 * and carry no third-party rights (we dedicate them to the public domain,
 * CC0). See fixtures/README.md for the layout of each file.
 *
 *   cc -O2 -I native/engine/tests/third_party native/engine/tests/tools/make_fixtures.c \
 *      -o /tmp/make_fixtures -lm && /tmp/make_fixtures native/engine/tests/fixtures
 */
#define DR_WAV_IMPLEMENTATION
#include "dr_wav.h"

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SR 48000
#define PI 3.14159265358979323846
#define SECONDS 8
#define N (SR * SECONDS)

static uint32_t rng = 12345u;
static double frand(void) { /* uniform [-1, 1) */
    rng = rng * 1664525u + 1013904223u;
    return (double)(rng >> 8) / 8388608.0 - 1.0;
}

static double db(double x) { return pow(10.0, x / 20.0); }

static void normalize_rms(float* x, size_t a, size_t b, double target_db) {
    double sum = 0.0;
    for (size_t i = a; i < b; i++) sum += (double)x[i] * x[i];
    double rms = sqrt(sum / (double)(b - a));
    double g = db(target_db) / rms;
    for (size_t i = 0; i < N; i++) x[i] = (float)(x[i] * g);
}

/* Vowel formants (F1, F2, F3) in Hz. */
static const double kVowels[5][3] = {
    {730, 1090, 2440}, {530, 1840, 2480}, {270, 2290, 3010}, {570, 840, 2410}, {300, 870, 2240}};

static double formant_gain(double f, const double* fm) {
    double g = 0.0;
    for (int k = 0; k < 3; k++) {
        double bw = 80.0 + 0.06 * fm[k];
        double d = (f - fm[k]) / bw;
        g += (k == 0 ? 1.0 : k == 1 ? 0.6 : 0.3) / (1.0 + d * d);
    }
    return g;
}

/*
 * Voice-like signal: harmonic source with a moving pitch, shaped by vowel
 * formants, in syllables. Silent before `start_s`; word pauses every 4
 * syllables. `gain_at(t)` scales it over time.
 */
static void synth_voice(float* out, double start_s, double (*gain_at)(double)) {
    double phase = 0.0;
    int syllable = -1;
    double syl_start = 0.0, syl_len = 0.0;
    const double* fm = kVowels[0];
    const double* fm_next = kVowels[1];
    double t = start_s;
    size_t i0 = (size_t)(start_s * SR);
    int count = 0;
    for (size_t i = i0; i < N; i++) {
        t = (double)i / SR;
        if (t >= syl_start + syl_len) {
            syllable++;
            count++;
            double gap = (count % 4 == 0) ? 0.35 : 0.06 + 0.04 * (frand() * 0.5 + 0.5);
            syl_start = t + gap;
            syl_len = 0.16 + 0.12 * (frand() * 0.5 + 0.5);
            fm = kVowels[syllable % 5];
            fm_next = kVowels[(syllable + 2) % 5];
        }
        double env = 0.0;
        if (t >= syl_start && t < syl_start + syl_len) {
            double u = (t - syl_start) / syl_len;
            env = sin(PI * u);
            env = env * env;
        }
        double f0 = 135.0 * (1.0 + 0.15 * sin(2 * PI * 0.7 * t) + 0.05 * sin(2 * PI * 3.1 * t));
        phase += f0 / SR;
        if (phase > 1.0) phase -= 1.0;
        if (env <= 0.0) continue;
        double u = (t - syl_start) / syl_len;
        double mix[3];
        for (int k = 0; k < 3; k++) mix[k] = fm[k] + (fm_next[k] - fm[k]) * 0.4 * u;
        double s = 0.0;
        for (int h = 1; h * f0 < 5000.0; h++) {
            s += formant_gain(h * f0, mix) / h * sin(2 * PI * phase * h);
        }
        s += 0.01 * frand(); /* breath */
        out[i] += (float)(env * s * gain_at(t));
    }
}

static double unity(double t) { (void)t; return 1.0; }
/* Near (0 dB) and far (−16 dB) halves, switching every 1.5 s. */
static double near_far(double t) { return ((int)((t - 1.0) / 1.5) % 2) ? db(-16.0) : 1.0; }

static void add_fan(float* x, double level_db) {
    float* n = (float*)calloc(N, sizeof(float));
    double lp1 = 0.0, lp2 = 0.0;
    for (size_t i = 0; i < N; i++) {
        double t = (double)i / SR;
        double w = frand();
        lp1 += 0.12 * (w - lp1); /* ~1 kHz */
        lp2 += 0.02 * (lp1 - lp2);
        double hum = 0.0;
        double wob = 1.0 + 0.003 * sin(2 * PI * 0.3 * t);
        for (int h = 1; h <= 4; h++) hum += 0.25 / h * sin(2 * PI * 100.0 * h * wob * t);
        n[i] = (float)(0.7 * lp1 + 0.6 * lp2 + 0.1 * w + 0.08 * hum);
    }
    normalize_rms(n, 0, N, level_db);
    for (size_t i = 0; i < N; i++) x[i] += n[i];
    free(n);
}

static void add_keyboard(float* x, double peak_db) {
    float* n = (float*)calloc(N, sizeof(float));
    size_t i = (size_t)(0.1 * SR);
    while (i < N) {
        double amp = 0.6 + 0.4 * (frand() * 0.5 + 0.5);
        double hp = 0.0, prev = 0.0;
        for (size_t k = 0; k < (size_t)(0.03 * SR) && i + k < N; k++) {
            double w = frand();
            hp = 0.9 * (hp + w - prev); /* high-pass */
            prev = w;
            double e = exp(-(double)k / (0.004 * SR));
            /* double click: key down and key up */
            if (k > (size_t)(0.012 * SR)) e += 0.5 * exp(-(double)(k - 0.012 * SR) / (0.003 * SR));
            n[i + k] += (float)(amp * hp * e);
        }
        i += (size_t)((0.09 + 0.16 * (frand() * 0.5 + 0.5)) * SR);
    }
    double peak = 0.0;
    for (size_t k = 0; k < N; k++) peak = fmax(peak, fabs(n[k]));
    for (size_t k = 0; k < N; k++) x[k] += (float)(n[k] / peak * db(peak_db) + 0.0005 * frand());
    free(n);
}

static int write_wav(const char* dir, const char* name, const float* x) {
    char path[1024];
    snprintf(path, sizeof path, "%s/%s", dir, name);
    drwav_data_format fmt;
    memset(&fmt, 0, sizeof fmt);
    fmt.container = drwav_container_riff;
    fmt.format = DR_WAVE_FORMAT_PCM;
    fmt.channels = 1;
    fmt.sampleRate = SR;
    fmt.bitsPerSample = 16;
    drwav wav;
    if (!drwav_init_file_write(&wav, path, &fmt, NULL)) return -1;
    int16_t* pcm = (int16_t*)malloc(N * sizeof(int16_t));
    for (size_t i = 0; i < N; i++) {
        double v = fmax(-1.0, fmin(1.0, x[i]));
        pcm[i] = (int16_t)lrint(v * 32767.0);
    }
    drwav_write_pcm_frames(&wav, N, pcm);
    drwav_uninit(&wav);
    free(pcm);
    printf("wrote %s\n", path);
    return 0;
}

int main(int argc, char** argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s <fixtures-dir>\n", argv[0]);
        return 1;
    }
    const char* dir = argv[1];
    float* x = (float*)calloc(N, sizeof(float));

    /* fan_speech: fan only for 0–2 s, then voice at −20 dBFS over fan at −35 dBFS. */
    rng = 1;
    synth_voice(x, 2.0, unity);
    normalize_rms(x, (size_t)(2.0 * SR), N, -22.0);
    add_fan(x, -35.0);
    write_wav(dir, "fan_speech.wav", x);

    /* keyboard: typing only for 0–2 s, then voice over typing (clicks peak −12 dBFS). */
    memset(x, 0, N * sizeof(float));
    rng = 2;
    synth_voice(x, 2.0, unity);
    normalize_rms(x, (size_t)(2.0 * SR), N, -22.0);
    add_keyboard(x, -12.0);
    write_wav(dir, "keyboard.wav", x);

    /* near_far_speech: voice from 1 s, alternating near/far every 1.5 s, light room noise. */
    memset(x, 0, N * sizeof(float));
    rng = 3;
    synth_voice(x, 1.0, near_far);
    normalize_rms(x, (size_t)(1.0 * SR), (size_t)(2.5 * SR), -18.0);
    add_fan(x, -55.0);
    write_wav(dir, "near_far_speech.wav", x);

    /* loud_laugh: normal voice, with very loud bursts (near full scale) 3–5 s. */
    memset(x, 0, N * sizeof(float));
    rng = 4;
    synth_voice(x, 1.0, unity);
    normalize_rms(x, (size_t)(1.0 * SR), N, -20.0);
    for (size_t i = (size_t)(3.0 * SR); i < (size_t)(5.0 * SR); i++) x[i] *= (float)db(17.0);
    add_fan(x, -55.0);
    write_wav(dir, "loud_laugh.wav", x);

    /* silence_noise: room noise only, −50 dBFS, no voice. */
    memset(x, 0, N * sizeof(float));
    rng = 5;
    add_fan(x, -50.0);
    write_wav(dir, "silence_noise.wav", x);

    free(x);
    return 0;
}
