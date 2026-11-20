/*
 * Lock-free single-producer / single-consumer ring buffer of float samples.
 *
 * Memory is allocated once in `me_ring_init` and freed in `me_ring_free`;
 * reads and writes never allocate, lock or block, so they are safe on the
 * audio threads. Exactly one thread may write and exactly one may read.
 */
#ifndef ME_RING_BUFFER_H
#define ME_RING_BUFFER_H

#include <stdatomic.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
    float* data;
    /* Capacity in samples; a power of two. */
    size_t capacity;
    size_t mask;
    /* Monotonic counters; their difference is the fill level. */
    _Atomic size_t write_pos;
    _Atomic size_t read_pos;
} me_ring;

/* Allocates a ring that holds at least `min_capacity` samples. Returns 0 on success. */
int me_ring_init(me_ring* ring, size_t min_capacity);

/* Frees the ring's memory. Safe on a zeroed or already-freed ring. */
void me_ring_free(me_ring* ring);

/* Number of samples ready to read. Callable from either side. */
size_t me_ring_available(const me_ring* ring);

/* Number of samples that can be written without overwriting unread data. */
size_t me_ring_space(const me_ring* ring);

/* Producer: writes up to `count` samples; returns how many were written. */
size_t me_ring_write(me_ring* ring, const float* src, size_t count);

/* Consumer: reads up to `count` samples; returns how many were read. */
size_t me_ring_read(me_ring* ring, float* dst, size_t count);

/* Consumer: discards up to `count` samples; returns how many were dropped. */
size_t me_ring_skip(me_ring* ring, size_t count);

/*
 * Resets both positions to empty. Only call while neither side is running
 * (for example between device stop and start).
 */
void me_ring_reset(me_ring* ring);

#endif /* ME_RING_BUFFER_H */
