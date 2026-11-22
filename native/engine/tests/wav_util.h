/* WAV helpers for the fixture tests (dr_wav, MIT-0 / public domain). */
#ifndef ME_WAV_UTIL_H
#define ME_WAV_UTIL_H

#include <stddef.h>

/* Loads a mono 48 kHz WAV as floats (caller frees). Returns NULL on error. */
float* me_wav_load(const char* path, size_t* frames);

/* Path of fixture `name` inside ME_FIXTURES_DIR. */
const char* me_fixture_path(const char* name);

/* RMS of samples [start_s, end_s) in dBFS (floor −120). */
double me_rms_db(const float* x, size_t frames, double start_s, double end_s);

/* Peak of samples [start_s, end_s) in dBFS (floor −120). */
double me_peak_db(const float* x, size_t frames, double start_s, double end_s);

#endif /* ME_WAV_UTIL_H */
