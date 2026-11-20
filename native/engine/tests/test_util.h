/* Minimal assertion helpers for the native CTest suite. */
#ifndef ME_TEST_UTIL_H
#define ME_TEST_UTIL_H

#include <stdio.h>
#include <stdlib.h>

static int me_test_failures = 0;

#define CHECK(cond)                                                       \
    do {                                                                  \
        if (!(cond)) {                                                    \
            fprintf(stderr, "%s:%d: CHECK failed: %s\n", __FILE__, __LINE__, #cond); \
            me_test_failures++;                                           \
        }                                                                 \
    } while (0)

#define CHECK_EQ_INT(a, b)                                                           \
    do {                                                                             \
        long long _a = (long long)(a), _b = (long long)(b);                          \
        if (_a != _b) {                                                              \
            fprintf(stderr, "%s:%d: CHECK_EQ failed: %s == %s (%lld vs %lld)\n",     \
                    __FILE__, __LINE__, #a, #b, _a, _b);                             \
            me_test_failures++;                                                      \
        }                                                                            \
    } while (0)

#define TEST_RESULT()                                               \
    do {                                                            \
        if (me_test_failures) {                                     \
            fprintf(stderr, "%d check(s) failed\n", me_test_failures); \
            return EXIT_FAILURE;                                    \
        }                                                           \
        printf("ok\n");                                             \
        return EXIT_SUCCESS;                                        \
    } while (0)

#endif /* ME_TEST_UTIL_H */
