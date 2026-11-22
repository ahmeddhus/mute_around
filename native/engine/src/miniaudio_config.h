/* miniaudio build options shared by every file that includes miniaudio.h. */
#ifndef ME_MINIAUDIO_CONFIG_H
#define ME_MINIAUDIO_CONFIG_H

#define MA_NO_DECODING
#define MA_NO_ENCODING
#define MA_NO_GENERATION
#define MA_NO_RESOURCE_MANAGER
#define MA_NO_NODE_GRAPH
#define MA_NO_ENGINE
#define MA_ENABLE_ONLY_SPECIFIC_BACKENDS
#define MA_ENABLE_COREAUDIO
#define MA_ENABLE_WASAPI
#define MA_ENABLE_NULL
#if defined(__APPLE__)
/* Link Core Audio directly instead of dlopen-ing it at runtime. */
#define MA_NO_RUNTIME_LINKING
#endif

#include "miniaudio.h"

#endif /* ME_MINIAUDIO_CONFIG_H */
