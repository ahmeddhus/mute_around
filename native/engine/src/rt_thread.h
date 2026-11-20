/* Minimal thread wrapper with real-time priority for the processing thread. */
#ifndef ME_RT_THREAD_H
#define ME_RT_THREAD_H

#include <stdint.h>

#if defined(_WIN32)
typedef void* me_thread; /* HANDLE */
#else
#include <pthread.h>
typedef pthread_t me_thread;
#endif

typedef void (*me_thread_fn)(void* arg);

/* Starts `fn(arg)` on a new thread. Returns 0 on success. */
int me_thread_start(me_thread* thread, me_thread_fn fn, void* arg);

/* Waits for the thread to finish. */
void me_thread_join(me_thread thread);

/*
 * Raises the calling thread's priority for audio work: macOS QoS
 * USER_INTERACTIVE, Windows MMCSS "Pro Audio". Returns an opaque token for
 * me_thread_end_realtime (Windows only; NULL elsewhere).
 */
void* me_thread_begin_realtime(void);
void me_thread_end_realtime(void* token);

/* Monotonic time in microseconds. Wait-free. */
uint64_t me_now_us(void);

/* Sleeps for about `us` microseconds. */
void me_sleep_us(uint32_t us);

#endif /* ME_RT_THREAD_H */
