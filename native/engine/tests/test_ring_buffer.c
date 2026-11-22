#include <string.h>

#include "ring_buffer.h"
#include "rt_thread.h"
#include "test_util.h"

static void test_empty_and_full(void) {
    me_ring ring;
    CHECK_EQ_INT(me_ring_init(&ring, 5), 0);
    CHECK_EQ_INT(ring.capacity, 8);
    CHECK_EQ_INT(me_ring_available(&ring), 0);
    CHECK_EQ_INT(me_ring_space(&ring), 8);

    float out[16];
    CHECK_EQ_INT(me_ring_read(&ring, out, 4), 0);

    float in[16];
    for (int i = 0; i < 16; i++) in[i] = (float)i;
    CHECK_EQ_INT(me_ring_write(&ring, in, 16), 8);
    CHECK_EQ_INT(me_ring_space(&ring), 0);
    CHECK_EQ_INT(me_ring_write(&ring, in, 1), 0);

    CHECK_EQ_INT(me_ring_read(&ring, out, 16), 8);
    for (int i = 0; i < 8; i++) CHECK(out[i] == (float)i);
    me_ring_free(&ring);
    me_ring_free(&ring); /* double free is safe */
}

static void test_wraparound(void) {
    me_ring ring;
    CHECK_EQ_INT(me_ring_init(&ring, 8), 0);
    float in[8], out[8];
    float next = 0.0f, expect = 0.0f;
    for (int round = 0; round < 100; round++) {
        size_t n = (size_t)(round % 7) + 1;
        for (size_t i = 0; i < n; i++) in[i] = next++;
        CHECK_EQ_INT(me_ring_write(&ring, in, n), n);
        CHECK_EQ_INT(me_ring_read(&ring, out, n), n);
        for (size_t i = 0; i < n; i++) CHECK(out[i] == expect++);
    }
    CHECK_EQ_INT(me_ring_write(&ring, in, 3), 3);
    CHECK_EQ_INT(me_ring_skip(&ring, 2), 2);
    CHECK_EQ_INT(me_ring_available(&ring), 1);
    me_ring_reset(&ring);
    CHECK_EQ_INT(me_ring_available(&ring), 0);
    me_ring_free(&ring);
}

#define TOTAL_SAMPLES 2000000

static void producer(void* arg) {
    me_ring* ring = (me_ring*)arg;
    float chunk[97];
    float next = 0.0f;
    size_t written = 0;
    while (written < TOTAL_SAMPLES) {
        size_t n = sizeof chunk / sizeof chunk[0];
        if (n > TOTAL_SAMPLES - written) n = TOTAL_SAMPLES - written;
        for (size_t i = 0; i < n; i++) chunk[i] = next + (float)i;
        size_t done = me_ring_write(ring, chunk, n);
        next += (float)done;
        written += done;
    }
}

static void test_concurrent(void) {
    me_ring ring;
    CHECK_EQ_INT(me_ring_init(&ring, 1024), 0);
    me_thread thread;
    CHECK_EQ_INT(me_thread_start(&thread, producer, &ring), 0);

    float chunk[61];
    size_t read = 0;
    int ordered = 1;
    while (read < TOTAL_SAMPLES) {
        size_t n = me_ring_read(&ring, chunk, sizeof chunk / sizeof chunk[0]);
        /* Floats are exact for integers below 2^24 > TOTAL_SAMPLES. */
        for (size_t i = 0; i < n; i++) {
            if (chunk[i] != (float)(read + i)) ordered = 0;
        }
        read += n;
    }
    me_thread_join(thread);
    CHECK(ordered);
    CHECK_EQ_INT(read, TOTAL_SAMPLES);
    me_ring_free(&ring);
}

int main(void) {
    test_empty_and_full();
    test_wraparound();
    test_concurrent();
    TEST_RESULT();
}
