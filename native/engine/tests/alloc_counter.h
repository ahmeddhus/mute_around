/*
 * Counts heap allocations made by the current process, for the real-time
 * allocation test.
 *
 * macOS: dyld interposing of the malloc family. It is built as its own dylib
 *   (dyld never interposes calls made inside the interposing image, and the
 *   engine and libDF are linked statically into the test binary).
 * Windows: installs a CRT allocation hook (_CrtSetAllocHook, debug CRT).
 */
#ifndef ME_ALLOC_COUNTER_H
#define ME_ALLOC_COUNTER_H


/* Starts counting allocations made by any thread. */
void me_alloc_counter_install(void);

/* Number of allocations counted since install. */
long me_alloc_counter_get(void);

#endif /* ME_ALLOC_COUNTER_H */
