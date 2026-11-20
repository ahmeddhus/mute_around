#include "rt_thread.h"

#include <stdlib.h>

#if defined(_WIN32)
#include <windows.h>
#include <avrt.h>
#include <process.h>
#else
#include <time.h>
#include <unistd.h>
#if defined(__APPLE__)
#include <pthread/qos.h>
#endif
#endif

typedef struct {
    me_thread_fn fn;
    void* arg;
} me_thread_start_info;

#if defined(_WIN32)
static unsigned __stdcall me_thread_trampoline(void* p) {
    me_thread_start_info info = *(me_thread_start_info*)p;
    free(p);
    info.fn(info.arg);
    return 0;
}

int me_thread_start(me_thread* thread, me_thread_fn fn, void* arg) {
    me_thread_start_info* info = (me_thread_start_info*)malloc(sizeof *info);
    if (info == NULL) return -1;
    info->fn = fn;
    info->arg = arg;
    uintptr_t h = _beginthreadex(NULL, 0, me_thread_trampoline, info, 0, NULL);
    if (h == 0) {
        free(info);
        return -1;
    }
    *thread = (me_thread)h;
    return 0;
}

void me_thread_join(me_thread thread) {
    WaitForSingleObject((HANDLE)thread, INFINITE);
    CloseHandle((HANDLE)thread);
}

void* me_thread_begin_realtime(void) {
    DWORD index = 0;
    return (void*)AvSetMmThreadCharacteristicsW(L"Pro Audio", &index);
}

void me_thread_end_realtime(void* token) {
    if (token != NULL) AvRevertMmThreadCharacteristics((HANDLE)token);
}

uint64_t me_now_us(void) {
    static LARGE_INTEGER freq;
    LARGE_INTEGER now;
    if (freq.QuadPart == 0) QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&now);
    return (uint64_t)(now.QuadPart * 1000000 / freq.QuadPart);
}

void me_sleep_us(uint32_t us) { Sleep(us < 1000 ? 1 : us / 1000); }
#else
static void* me_thread_trampoline(void* p) {
    me_thread_start_info info = *(me_thread_start_info*)p;
    free(p);
    info.fn(info.arg);
    return NULL;
}

int me_thread_start(me_thread* thread, me_thread_fn fn, void* arg) {
    me_thread_start_info* info = (me_thread_start_info*)malloc(sizeof *info);
    if (info == NULL) return -1;
    info->fn = fn;
    info->arg = arg;
    if (pthread_create(thread, NULL, me_thread_trampoline, info) != 0) {
        free(info);
        return -1;
    }
    return 0;
}

void me_thread_join(me_thread thread) { pthread_join(thread, NULL); }

void* me_thread_begin_realtime(void) {
#if defined(__APPLE__)
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
#endif
    return NULL;
}

void me_thread_end_realtime(void* token) { (void)token; }

uint64_t me_now_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000u + (uint64_t)ts.tv_nsec / 1000u;
}

void me_sleep_us(uint32_t us) {
    struct timespec ts = {(time_t)(us / 1000000u), (long)(us % 1000000u) * 1000L};
    nanosleep(&ts, NULL);
}
#endif
