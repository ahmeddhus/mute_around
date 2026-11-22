/* Allocation counter for test_no_alloc; see alloc_counter.h. */
#include "alloc_counter.h"

#include <stdatomic.h>
#include <stddef.h>

static _Atomic long me_alloc_count = 0;

#if defined(__APPLE__)
/*
 * dyld interposing: every call to these functions from any image (including
 * the Rust allocator inside libmute_df) is routed through the counters.
 * Counting is off until me_alloc_counter_install() runs.
 */
#include <malloc/malloc.h>
#include <stdlib.h>

static _Atomic int me_alloc_counting = 0;

#define ME_COUNT() \
    do { if (atomic_load_explicit(&me_alloc_counting, memory_order_relaxed)) \
        atomic_fetch_add(&me_alloc_count, 1); } while (0)

static void* me_malloc(size_t n) { ME_COUNT(); return malloc(n); }
static void* me_calloc(size_t c, size_t n) { ME_COUNT(); return calloc(c, n); }
static void* me_realloc(void* p, size_t n) { ME_COUNT(); return realloc(p, n); }
static void* me_valloc(size_t n) { ME_COUNT(); return valloc(n); }
static int me_posix_memalign(void** p, size_t a, size_t n) { ME_COUNT(); return posix_memalign(p, a, n); }
static void* me_aligned_alloc(size_t a, size_t n) { ME_COUNT(); return aligned_alloc(a, n); }
static void* me_malloc_zone_malloc(malloc_zone_t* z, size_t n) { ME_COUNT(); return malloc_zone_malloc(z, n); }
static void* me_malloc_zone_memalign(malloc_zone_t* z, size_t a, size_t n) { ME_COUNT(); return malloc_zone_memalign(z, a, n); }

#define ME_INTERPOSE(repl, orig)                                                       \
    __attribute__((used)) static struct { const void* r; const void* o; }            \
        me_interpose_##orig __attribute__((section("__DATA,__interpose"))) = {         \
            (const void*)(unsigned long)&repl, (const void*)(unsigned long)&orig}

ME_INTERPOSE(me_malloc, malloc);
ME_INTERPOSE(me_calloc, calloc);
ME_INTERPOSE(me_realloc, realloc);
ME_INTERPOSE(me_valloc, valloc);
ME_INTERPOSE(me_posix_memalign, posix_memalign);
ME_INTERPOSE(me_aligned_alloc, aligned_alloc);
ME_INTERPOSE(me_malloc_zone_malloc, malloc_zone_malloc);
ME_INTERPOSE(me_malloc_zone_memalign, malloc_zone_memalign);

void me_alloc_counter_install(void) { atomic_store(&me_alloc_counting, 1); }
#elif defined(_WIN32)
#include <crtdbg.h>

static int me_alloc_hook(int type, void* data, size_t size, int block, long req,
                         const unsigned char* file, int line) {
    (void)data; (void)size; (void)block; (void)req; (void)file; (void)line;
    if (type == _HOOK_ALLOC || type == _HOOK_REALLOC) atomic_fetch_add(&me_alloc_count, 1);
    return 1;
}

void me_alloc_counter_install(void) { _CrtSetAllocHook(me_alloc_hook); }
#else
#error "alloc_counter.h supports macOS and Windows only"
#endif

long me_alloc_counter_get(void) { return atomic_load(&me_alloc_count); }

