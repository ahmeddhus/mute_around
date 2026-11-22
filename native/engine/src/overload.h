/*
 * Overload detector: decides when the computer
 * is too busy for real-time noise suppression, so the engine passes raw
 * audio instead of crackling, and when it may try again.
 *
 * - Enter after ME_OVERLOAD_ENTER_HOPS consecutive hops whose processing
 *   took more than ME_OVERLOAD_ENTER_RATIO of the hop period, or on an
 *   output underrun while input was waiting (the processing thread fell
 *   behind; an underrun without waiting input just means no microphone).
 * - Leave after a calm window in which every hop took less than
 *   ME_OVERLOAD_EXIT_RATIO of the period and nothing underran.
 *
 * While overloaded the engine skips noise suppression, so the hop times it
 * reports then say little about the real load: the calm window would end
 * after 5 s however busy the computer is. To keep sustained load from
 * cycling in and out (a glitch on every re-entry), the window backs off:
 * re-entering within ME_OVERLOAD_RELAPSE_MS of leaving doubles it, up to
 * ME_OVERLOAD_EXIT_MAX_MS; staying out that long resets it to
 * ME_OVERLOAD_EXIT_MS. This costs no processing, unlike timing trial hops
 * of noise suppression, which on a loaded machine could themselves run
 * late and underrun.
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
#define ME_OVERLOAD_EXIT_MAX_MS 80000.0f
#define ME_OVERLOAD_RELAPSE_MS 10000.0f

typedef struct {
    int active;
    int slow_hops;       /* consecutive slow hops while not active */
    float calm_ms;       /* time spent calm while active */
    float exit_ms;       /* calm time needed to leave (backs off on relapse) */
    float since_exit_ms; /* time since leaving; < 0 when not recently left */
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
