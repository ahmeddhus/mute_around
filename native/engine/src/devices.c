#include <stdio.h>
#include <string.h>

#include "engine_internal.h"

#if defined(_WIN32)
#include <windows.h>
#endif

void me_device_id_to_string(const ma_context* context, const ma_device_id* id, char* out,
                            size_t cap) {
    if (cap == 0) return;
    out[0] = '\0';
    switch (context->backend) {
        case ma_backend_coreaudio:
            snprintf(out, cap, "%s", id->coreaudio);
            break;
#if defined(_WIN32)
        case ma_backend_wasapi: {
            int n = WideCharToMultiByte(CP_UTF8, 0, (const wchar_t*)id->wasapi, -1, out,
                                        (int)cap, NULL, NULL);
            if (n <= 0) out[0] = '\0';
            out[cap - 1] = '\0';
            break;
        }
#endif
        case ma_backend_null:
            snprintf(out, cap, "null:%d", id->nullbackend);
            break;
        default: {
            /* Unknown backend: hex of the raw bytes, still stable. */
            const unsigned char* bytes = (const unsigned char*)id;
            size_t pos = 0;
            for (size_t i = 0; i < sizeof *id && pos + 3 <= cap; i++) {
                pos += (size_t)snprintf(out + pos, cap - pos, "%02x", bytes[i]);
            }
            break;
        }
    }
}

static void copy_name(char* dst, size_t cap, const char* name, const char* id) {
    if (name[0] != '\0') {
        snprintf(dst, cap, "%s", name);
        return;
    }
    /* The ABI promises a non-empty name. */
    size_t len = strlen(id);
    snprintf(dst, cap, "Microphone (%s)", len > 6 ? id + len - 6 : id);
}

int32_t me_list_devices(me_engine* engine, me_device_kind kind, me_device_info* buf,
                        int32_t cap) {
    if (engine == NULL || cap < 0 || (cap > 0 && buf == NULL)) return ME_ERR_INVALID_ARG;
    if (kind != ME_DEVICE_CAPTURE && kind != ME_DEVICE_PLAYBACK) return ME_ERR_INVALID_ARG;

    ma_device_info* playback = NULL;
    ma_device_info* capture = NULL;
    ma_uint32 playback_count = 0;
    ma_uint32 capture_count = 0;
    ma_result r = ma_context_get_devices(&engine->context, &playback, &playback_count, &capture,
                                         &capture_count);
    if (r != MA_SUCCESS) {
        me_set_error(engine, "Could not list audio devices: %s", ma_result_description(r));
        return ME_ERR_DEVICE;
    }

    ma_device_info* infos = kind == ME_DEVICE_CAPTURE ? capture : playback;
    ma_uint32 count = kind == ME_DEVICE_CAPTURE ? capture_count : playback_count;
    for (ma_uint32 i = 0; i < count && (int32_t)i < cap; i++) {
        me_device_info* dst = &buf[i];
        me_device_id_to_string(&engine->context, &infos[i].id, dst->id, sizeof dst->id);
        copy_name(dst->name, sizeof dst->name, infos[i].name, dst->id);
        dst->is_default = infos[i].isDefault ? 1 : 0;
    }
    return (int32_t)count;
}

me_result me_find_device(me_engine* engine, ma_device_type type, const char* id,
                         ma_device_id* out) {
    ma_device_info* playback = NULL;
    ma_device_info* capture = NULL;
    ma_uint32 playback_count = 0;
    ma_uint32 capture_count = 0;
    ma_result r = ma_context_get_devices(&engine->context, &playback, &playback_count, &capture,
                                         &capture_count);
    if (r != MA_SUCCESS) {
        me_set_error(engine, "Could not list audio devices: %s", ma_result_description(r));
        return ME_ERR_DEVICE;
    }

    ma_device_info* infos = type == ma_device_type_capture ? capture : playback;
    ma_uint32 count = type == ma_device_type_capture ? capture_count : playback_count;
    char candidate[ME_DEVICE_ID_MAX];
    for (ma_uint32 i = 0; i < count; i++) {
        me_device_id_to_string(&engine->context, &infos[i].id, candidate, sizeof candidate);
        if (strcmp(candidate, id) == 0) {
            *out = infos[i].id;
            return ME_OK;
        }
    }
    me_set_error(engine, "No %s device with id \"%s\"",
                 type == ma_device_type_capture ? "input" : "output", id);
    return ME_ERR_NOT_FOUND;
}
