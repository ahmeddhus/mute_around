#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "engine_internal.h"

void me_atomic_store_float(_Atomic uint32_t* slot, float value) {
    uint32_t bits;
    memcpy(&bits, &value, sizeof bits);
    atomic_store_explicit(slot, bits, memory_order_relaxed);
}

float me_atomic_load_float(_Atomic uint32_t* slot) {
    uint32_t bits = atomic_load_explicit(slot, memory_order_relaxed);
    float value;
    memcpy(&value, &bits, sizeof value);
    return value;
}

void me_set_error(me_engine* engine, const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vsnprintf(engine->last_error, sizeof engine->last_error, fmt, args);
    va_end(args);
}

uint32_t me_abi_version(void) {
    return ((uint32_t)ME_ABI_VERSION_MAJOR << 16) | (uint32_t)ME_ABI_VERSION_MINOR;
}

static me_result map_device_error(me_engine* engine, ma_result r, const char* what) {
    me_set_error(engine, "Could not open the %s: %s", what, ma_result_description(r));
    return r == MA_ACCESS_DENIED ? ME_ERR_PERMISSION_DENIED : ME_ERR_DEVICE;
}

/* --- Device callbacks: copy only. --- */

static void capture_callback(ma_device* device, void* output, const void* input,
                             ma_uint32 frames) {
    (void)output;
    me_engine* engine = (me_engine*)device->pUserData;
    /* If the processing thread fell behind the overflow is dropped. */
    me_ring_write(&engine->ring_in, (const float*)input, frames);
}

static void playback_callback(ma_device* device, void* output, const void* input,
                              ma_uint32 frames) {
    (void)input;
    me_engine* engine = (me_engine*)device->pUserData;
    float* out = (float*)output;
    size_t got = 0;

    if (!atomic_load_explicit(&engine->playback_primed, memory_order_relaxed)) {
        if (me_ring_available(&engine->ring_out) >= ME_PRIME_FILL) {
            atomic_store_explicit(&engine->playback_primed, 1, memory_order_relaxed);
        }
    }
    if (atomic_load_explicit(&engine->playback_primed, memory_order_relaxed)) {
        got = me_ring_read(&engine->ring_out, out, frames);
        if (got < frames) {
            /* Underrun: output silence and re-prime so playback resumes cleanly. */
            atomic_fetch_add_explicit(&engine->underruns, 1, memory_order_relaxed);
            atomic_store_explicit(&engine->playback_primed, 0, memory_order_relaxed);
        }
    }
    if (got < frames) memset(out + got, 0, (frames - got) * sizeof(float));
}

static void capture_notification(const ma_device_notification* notification) {
    if (notification->type != ma_device_notification_type_stopped) return;
    me_engine* engine = (me_engine*)notification->pDevice->pUserData;
    /* A stop we didn't ask for means the device went away (unplugged, or a
     * Bluetooth headset switching profile). The sink then gets silence. */
    if (!atomic_load(&engine->capture_stopping)) {
        int32_t expected = ME_STATUS_RUNNING;
        atomic_compare_exchange_strong(&engine->status, &expected, ME_STATUS_DEVICE_DISCONNECTED);
    }
}

static ma_device_config device_config(ma_device_type type, const ma_device_id* id,
                                      me_engine* engine) {
    ma_device_config config = ma_device_config_init(type);
    config.sampleRate = ME_SAMPLE_RATE;
    config.periodSizeInFrames = ME_PERIOD_FRAMES;
    config.performanceProfile = ma_performance_profile_low_latency;
    config.noPreSilencedOutputBuffer = MA_TRUE;
    config.pUserData = engine;
    if (type == ma_device_type_capture) {
        config.capture.pDeviceID = id;
        config.capture.format = ma_format_f32;
        config.capture.channels = 1;
        config.dataCallback = capture_callback;
        config.notificationCallback = capture_notification;
    } else {
        config.playback.pDeviceID = id;
        config.playback.format = ma_format_f32;
        config.playback.channels = 1;
        config.dataCallback = playback_callback;
    }
    return config;
}

/* Opens and starts the capture device. Control thread only. */
static me_result open_capture(me_engine* engine, const char* capture_id) {
    ma_device_id id;
    if (capture_id != NULL) {
        me_result r = me_find_device(engine, ma_device_type_capture, capture_id, &id);
        if (r != ME_OK) return r;
    }
    ma_device_config config =
        device_config(ma_device_type_capture, capture_id != NULL ? &id : NULL, engine);
    ma_result r = ma_device_init(&engine->context, &config, &engine->capture);
    if (r != MA_SUCCESS) return map_device_error(engine, r, "microphone");
    engine->capture_open = 1;
    atomic_store(&engine->capture_stopping, 0);
    r = ma_device_start(&engine->capture);
    if (r != MA_SUCCESS) {
        atomic_store(&engine->capture_stopping, 1);
        ma_device_uninit(&engine->capture);
        engine->capture_open = 0;
        return map_device_error(engine, r, "microphone");
    }
    return ME_OK;
}

static void close_capture(me_engine* engine) {
    if (!engine->capture_open) return;
    atomic_store(&engine->capture_stopping, 1);
    ma_device_uninit(&engine->capture);
    engine->capture_open = 0;
}

static void close_playback(me_engine* engine) {
    if (!engine->playback_open) return;
    ma_device_uninit(&engine->playback);
    engine->playback_open = 0;
}

static void stop_processing(me_engine* engine) {
    if (!atomic_load(&engine->proc_run)) return;
    atomic_store_explicit(&engine->proc_run, 0, memory_order_release);
    me_thread_join(engine->proc_thread);
}

me_result me_engine_create(const char* model_path, me_engine** out) {
    if (out == NULL) return ME_ERR_INVALID_ARG;
    *out = NULL;

    me_engine* engine = (me_engine*)calloc(1, sizeof *engine);
    if (engine == NULL) return ME_ERR_DEVICE;
    atomic_init(&engine->bypass, 0);
    atomic_init(&engine->agc, 1);
    atomic_init(&engine->strength, ME_STRENGTH_MEDIUM);
    atomic_init(&engine->status, ME_STATUS_STOPPED);

    char err[ME_ERROR_MAX] = {0};
    engine->dfn = mdf_create(model_path, me_strength_attenuation_db(ME_STRENGTH_MEDIUM), err,
                             sizeof err);
    if (engine->dfn == NULL) {
        free(engine);
        return ME_ERR_MODEL;
    }
    if (mdf_frame_length(engine->dfn) != ME_HOP) {
        mdf_free(engine->dfn);
        free(engine);
        return ME_ERR_MODEL;
    }

    /* Test hook (documented in mute_engine.h): read once, here only. */
    const char* backend = getenv("MUTE_ENGINE_BACKEND");
    engine->null_backend = backend != NULL && strcmp(backend, "null") == 0;
    ma_backend null_only[] = {ma_backend_null};
    ma_result r = ma_context_init(engine->null_backend ? null_only : NULL,
                                  engine->null_backend ? 1 : 0, NULL, &engine->context);
    if (r != MA_SUCCESS || me_ring_init(&engine->ring_in, ME_RING_CAPACITY) != 0 ||
        me_ring_init(&engine->ring_out, ME_RING_CAPACITY) != 0) {
        if (r == MA_SUCCESS) ma_context_uninit(&engine->context);
        me_ring_free(&engine->ring_in);
        mdf_free(engine->dfn);
        free(engine);
        return ME_ERR_DEVICE;
    }

    me_processing_reset(engine);
    *out = engine;
    return ME_OK;
}

void me_engine_destroy(me_engine* engine) {
    if (engine == NULL) return;
    if (engine->running) me_engine_stop(engine);
    ma_context_uninit(&engine->context);
    mdf_free(engine->dfn);
    me_ring_free(&engine->ring_in);
    me_ring_free(&engine->ring_out);
    free(engine);
}

me_result me_engine_start(me_engine* engine, const char* capture_id, const char* sink_id) {
    if (engine == NULL) return ME_ERR_INVALID_ARG;
    if (engine->running) {
        me_set_error(engine, "The engine is already running");
        return ME_ERR_STATE;
    }

    ma_device_id sink;
    if (sink_id != NULL) {
        me_result r = me_find_device(engine, ma_device_type_playback, sink_id, &sink);
        if (r != ME_OK) return r;
    }
    if (capture_id != NULL) {
        /* Check now so a bad id fails before anything is opened. */
        ma_device_id unused;
        me_result r = me_find_device(engine, ma_device_type_capture, capture_id, &unused);
        if (r != ME_OK) return r;
    }

    me_ring_reset(&engine->ring_in);
    me_ring_reset(&engine->ring_out);
    me_drift_reset(&engine->drift);
    atomic_store(&engine->playback_primed, 0);
    atomic_store(&engine->frames_processed, 0);
    atomic_store(&engine->underruns, 0);
    me_atomic_store_float(&engine->avg_process_ms_bits, 0.0f);
    me_atomic_store_float(&engine->avg_out_fill_bits, 0.0f);
    atomic_store(&engine->overload_events, 0);
    me_processing_reset(engine);

    ma_device_config config =
        device_config(ma_device_type_playback, sink_id != NULL ? &sink : NULL, engine);
    ma_result mr = ma_device_init(&engine->context, &config, &engine->playback);
    if (mr != MA_SUCCESS) return map_device_error(engine, mr, "virtual microphone");
    engine->playback_open = 1;

    atomic_store(&engine->proc_run, 1);
    if (me_thread_start(&engine->proc_thread, me_processing_main, engine) != 0) {
        atomic_store(&engine->proc_run, 0);
        close_playback(engine);
        me_set_error(engine, "Could not start the processing thread");
        return ME_ERR_DEVICE;
    }

    mr = ma_device_start(&engine->playback);
    if (mr != MA_SUCCESS) {
        stop_processing(engine);
        close_playback(engine);
        return map_device_error(engine, mr, "virtual microphone");
    }

    me_result r = open_capture(engine, capture_id);
    if (r != ME_OK) {
        stop_processing(engine);
        close_playback(engine);
        return r;
    }

    engine->running = 1;
    atomic_store(&engine->status, ME_STATUS_RUNNING);
    return ME_OK;
}

me_result me_engine_switch_input(me_engine* engine, const char* capture_id) {
    if (engine == NULL) return ME_ERR_INVALID_ARG;
    if (!engine->running) {
        me_set_error(engine, "The engine is not running");
        return ME_ERR_STATE;
    }
    if (capture_id != NULL) {
        ma_device_id unused;
        me_result r = me_find_device(engine, ma_device_type_capture, capture_id, &unused);
        if (r != ME_OK) return r;
    }
    /* The sink keeps running and outputs silence until the new mic delivers. */
    close_capture(engine);
    me_result r = open_capture(engine, capture_id);
    atomic_store(&engine->status, r == ME_OK ? ME_STATUS_RUNNING : ME_STATUS_DEVICE_DISCONNECTED);
    return r;
}

me_result me_engine_stop(me_engine* engine) {
    if (engine == NULL) return ME_ERR_INVALID_ARG;
    if (!engine->running) {
        me_set_error(engine, "The engine is not running");
        return ME_ERR_STATE;
    }
    close_capture(engine);
    close_playback(engine);
    stop_processing(engine);
    /* The processing thread has exited, so the meters can be reset here. */
    me_levels_silence(&engine->levels);
    atomic_store(&engine->overloaded, 0);
    engine->running = 0;
    atomic_store(&engine->status, ME_STATUS_STOPPED);
    return ME_OK;
}

void me_set_bypass(me_engine* engine, uint8_t on) {
    if (engine != NULL) atomic_store_explicit(&engine->bypass, on ? 1 : 0, memory_order_relaxed);
}

void me_set_agc(me_engine* engine, uint8_t on) {
    if (engine != NULL) atomic_store_explicit(&engine->agc, on ? 1 : 0, memory_order_relaxed);
}

void me_set_strength(me_engine* engine, me_strength strength) {
    if (engine == NULL || strength < ME_STRENGTH_LOW || strength > ME_STRENGTH_HIGH) return;
    atomic_store_explicit(&engine->strength, (int32_t)strength, memory_order_relaxed);
}

me_status me_get_status(me_engine* engine) {
    if (engine == NULL) return ME_STATUS_ERROR;
    int32_t status = atomic_load_explicit(&engine->status, memory_order_relaxed);
    if (status != ME_STATUS_RUNNING) return status;
    /* The user's own bypass wins over the automatic one. */
    if (atomic_load_explicit(&engine->bypass, memory_order_relaxed)) {
        return ME_STATUS_BYPASSED_USER;
    }
    if (atomic_load_explicit(&engine->overloaded, memory_order_relaxed)) {
        return ME_STATUS_BYPASSED_OVERLOAD;
    }
    return status;
}

void me_get_levels(me_engine* engine, me_levels* out) {
    if (out == NULL) return;
    if (engine == NULL) {
        out->input_peak_db = out->input_rms_db = ME_LEVEL_FLOOR_DB;
        out->output_peak_db = out->output_rms_db = ME_LEVEL_FLOOR_DB;
        return;
    }
    me_levels_read(&engine->levels, out);
}

void me_get_stats(me_engine* engine, me_stats* out) {
    if (out == NULL) return;
    memset(out, 0, sizeof *out);
    if (engine == NULL) return;
    out->frames_processed = atomic_load_explicit(&engine->frames_processed, memory_order_relaxed);
    out->avg_process_ms = me_atomic_load_float(&engine->avg_process_ms_bits);
    out->underruns = atomic_load_explicit(&engine->underruns, memory_order_relaxed);
    out->overload_events = atomic_load_explicit(&engine->overload_events, memory_order_relaxed);
    /* Capture period + average wait for a full hop + DFN delay + output ring
     * + playback period. The virtual device's own buffering isn't included. */
    float period_ms = 1000.0f * ME_PERIOD_FRAMES / ME_SAMPLE_RATE;
    float hop_wait_ms = 0.5f * 1000.0f * ME_HOP / ME_SAMPLE_RATE;
    float out_ring_ms =
        1000.0f * (me_atomic_load_float(&engine->avg_out_fill_bits) + ME_HOP / 2.0f) /
        ME_SAMPLE_RATE;
    out->estimated_latency_ms =
        engine->running ? period_ms + hop_wait_ms + ME_DFN_DELAY_MS + out_ring_ms + period_ms
                        : 0.0f;
}

me_result me_last_error(me_engine* engine, char* buf, int32_t cap) {
    if (engine == NULL || buf == NULL || cap <= 0) return ME_ERR_INVALID_ARG;
    snprintf(buf, (size_t)cap, "%s", engine->last_error);
    return ME_OK;
}
