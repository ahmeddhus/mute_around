/*
 * mute_df.h — internal C API of the libDF shim (native/engine/dfshim).
 * Not part of the public ABI; only the engine includes it.
 */
#ifndef MUTE_DF_H
#define MUTE_DF_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MdfState MdfState;

/* model_path NULL → embedded DFN3 low-latency model. Returns NULL on error. */
MdfState* mdf_create(const char* model_path, float atten_lim_db, char* err, size_t err_cap);
size_t mdf_frame_length(const MdfState* st);
/* Returns local SNR (dB), or NaN on error. */
float mdf_process_frame(MdfState* st, const float* input, float* output);
void mdf_set_atten_lim(MdfState* st, float lim_db);
/*
 * Real-time allocation: after mdf_rt_enter(st) on a thread, Rust allocations
 * on that thread come from st's preallocated pool (no system heap, no locks).
 * Call mdf_rt_leave() before the thread exits and before mdf_free(st).
 */
void mdf_rt_enter(const MdfState* st);
void mdf_rt_leave(void);
/* System-heap fallbacks on entered threads; should stay 0. */
size_t mdf_rt_fallbacks(void);
void mdf_free(MdfState* st);

#ifdef __cplusplus
}
#endif

#endif /* MUTE_DF_H */
