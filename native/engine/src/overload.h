/*
 * Overload detector: decides when the computer
 * is too busy for real-time noise suppression, so the engine passes raw
 * audio instead of crackling, and when it may try again.
 *
 * - Enter after ME_OVERLOAD_ENTER_HOPS consecutive hops whose processing
 *   took more than ME_OVERLOAD_ENTER_RATIO of the hop period, or on an
 *   output underrun while input was waiting (the processing thread fell
 *   behind; an underrun without waiting input just means no microphone).
 * - Leave after ME_OVERLOAD_EXIT_MS in which every hop took less than
 *   ME_OVERLOAD_EXIT_RATIO of the period and nothing underran.
 *
 * The user's own bypass is separate and always wins in the reported status.
 * Pure state machine: no clock, no I/O; the caller passes the timings.
 */
#ifndef ME_OVERLOAD_H
#define ME_OVERLOAD_H

#define ME_OVERLOAD_ENTER_HOPS 3
#define ME_OVERLOAD_ENTER_RATIO 0.8f
#define ME_OVERLOAD_EXIT_RATIO 0.5f
#define ME_OVERLOAD_EXIT_MS 5000.0f

typedef struct {
    int active;
    int slow_hops; /* consecutive slow hops while not active */
    float calm_ms; /* time spent calm while active */
} me_overload;

void me_overload_reset(me_overload* ov);

/*
 * Feeds one hop: how long it took (`process_ms`) out of `period_ms`, and
 * whether the output underran while input was waiting. Returns 1 when the
 * detector has just entered overload, 0 otherwise; `ov->active` holds the
 * current state.
 */
int me_overload_update(me_overload* ov, float process_ms, float period_ms, int starved);

#endif /* ME_OVERLOAD_H */
