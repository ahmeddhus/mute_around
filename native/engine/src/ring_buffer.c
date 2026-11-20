#include "ring_buffer.h"

#include <stdlib.h>
#include <string.h>

static size_t next_pow2(size_t n) {
    size_t p = 1;
    while (p < n) p <<= 1;
    return p;
}

int me_ring_init(me_ring* ring, size_t min_capacity) {
    if (ring == NULL || min_capacity == 0) return -1;
    size_t capacity = next_pow2(min_capacity);
    float* data = (float*)calloc(capacity, sizeof(float));
    if (data == NULL) return -1;
    ring->data = data;
    ring->capacity = capacity;
    ring->mask = capacity - 1;
    atomic_init(&ring->write_pos, 0);
    atomic_init(&ring->read_pos, 0);
    return 0;
}

void me_ring_free(me_ring* ring) {
    if (ring == NULL) return;
    free(ring->data);
    ring->data = NULL;
    ring->capacity = 0;
    ring->mask = 0;
}

size_t me_ring_available(const me_ring* ring) {
    size_t w = atomic_load_explicit(&((me_ring*)ring)->write_pos, memory_order_acquire);
    size_t r = atomic_load_explicit(&((me_ring*)ring)->read_pos, memory_order_acquire);
    return w - r;
}

size_t me_ring_space(const me_ring* ring) { return ring->capacity - me_ring_available(ring); }

size_t me_ring_write(me_ring* ring, const float* src, size_t count) {
    size_t w = atomic_load_explicit(&ring->write_pos, memory_order_relaxed);
    size_t r = atomic_load_explicit(&ring->read_pos, memory_order_acquire);
    size_t space = ring->capacity - (w - r);
    if (count > space) count = space;
    if (count == 0) return 0;

    size_t start = w & ring->mask;
    size_t first = ring->capacity - start;
    if (first > count) first = count;
    memcpy(ring->data + start, src, first * sizeof(float));
    if (count > first) memcpy(ring->data, src + first, (count - first) * sizeof(float));

    atomic_store_explicit(&ring->write_pos, w + count, memory_order_release);
    return count;
}

size_t me_ring_read(me_ring* ring, float* dst, size_t count) {
    size_t r = atomic_load_explicit(&ring->read_pos, memory_order_relaxed);
    size_t w = atomic_load_explicit(&ring->write_pos, memory_order_acquire);
    size_t avail = w - r;
    if (count > avail) count = avail;
    if (count == 0) return 0;

    size_t start = r & ring->mask;
    size_t first = ring->capacity - start;
    if (first > count) first = count;
    memcpy(dst, ring->data + start, first * sizeof(float));
    if (count > first) memcpy(dst + first, ring->data, (count - first) * sizeof(float));

    atomic_store_explicit(&ring->read_pos, r + count, memory_order_release);
    return count;
}

size_t me_ring_skip(me_ring* ring, size_t count) {
    size_t r = atomic_load_explicit(&ring->read_pos, memory_order_relaxed);
    size_t w = atomic_load_explicit(&ring->write_pos, memory_order_acquire);
    size_t avail = w - r;
    if (count > avail) count = avail;
    atomic_store_explicit(&ring->read_pos, r + count, memory_order_release);
    return count;
}

void me_ring_reset(me_ring* ring) {
    atomic_store_explicit(&ring->write_pos, 0, memory_order_relaxed);
    atomic_store_explicit(&ring->read_pos, 0, memory_order_relaxed);
}
