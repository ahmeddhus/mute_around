#define DR_WAV_IMPLEMENTATION
#include "dr_wav.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "wav_util.h"

float* me_wav_load(const char* path, size_t* frames) {
    unsigned int channels = 0, rate = 0;
    drwav_uint64 count = 0;
    float* data = drwav_open_file_and_read_pcm_frames_f32(path, &channels, &rate, &count, NULL);
    if (data == NULL) {
        fprintf(stderr, "cannot read %s\n", path);
        return NULL;
    }
    if (channels != 1 || rate != 48000) {
        fprintf(stderr, "%s: expected mono 48 kHz, got %u ch %u Hz\n", path, channels, rate);
        drwav_free(data, NULL);
        return NULL;
    }
    /* Copy into malloc'd memory so callers can use free(). */
    float* copy = (float*)malloc((size_t)count * sizeof(float));
    if (copy != NULL) memcpy(copy, data, (size_t)count * sizeof(float));
    drwav_free(data, NULL);
    *frames = (size_t)count;
    return copy;
}

const char* me_fixture_path(const char* name) {
    static char path[1024];
    snprintf(path, sizeof path, "%s/%s", ME_FIXTURES_DIR, name);
    return path;
}

static void range(size_t frames, double start_s, double end_s, size_t* a, size_t* b) {
    *a = (size_t)(start_s * 48000.0);
    *b = (size_t)(end_s * 48000.0);
    if (*b > frames) *b = frames;
    if (*a > *b) *a = *b;
}

double me_rms_db(const float* x, size_t frames, double start_s, double end_s) {
    size_t a, b;
    range(frames, start_s, end_s, &a, &b);
    double sum = 0.0;
    for (size_t i = a; i < b; i++) sum += (double)x[i] * x[i];
    double rms = b > a ? sqrt(sum / (double)(b - a)) : 0.0;
    return rms > 1e-6 ? 20.0 * log10(rms) : -120.0;
}

double me_peak_db(const float* x, size_t frames, double start_s, double end_s) {
    size_t a, b;
    range(frames, start_s, end_s, &a, &b);
    double peak = 0.0;
    for (size_t i = a; i < b; i++) peak = fmax(peak, fabs((double)x[i]));
    return peak > 1e-6 ? 20.0 * log10(peak) : -120.0;
}
