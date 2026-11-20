# WAV fixtures

48 kHz, mono, 16-bit PCM, 8 s each. All five are **synthetic**, generated
from a fixed seed by [`../tools/make_fixtures.c`](../tools/make_fixtures.c),
so they're reproducible and carry no third-party rights. They're released
under **CC0 1.0** (public domain).

The "voice" is formant synthesis: a harmonic source with a moving pitch,
shaped by vowel formants, in syllables. It looks enough like speech to
DeepFilterNet to exercise the pipeline (local SNR, speech gating) and to
make the noise-floor and level checks meaningful. It is **not** a
substitute for real speech when judging quality. Replace these files with
self-recorded or CC0 speech for the listening test.

Regenerate:

```bash
cc -O2 -I native/engine/tests/third_party native/engine/tests/tools/make_fixtures.c -o /tmp/make_fixtures -lm
/tmp/make_fixtures native/engine/tests/fixtures
```

| File | Content | Noise-only range | Speech range | Used by |
|---|---|---|---|---|
| `fan_speech.wav` | Fan (low-passed noise + 100 Hz hum harmonics) at −35 dBFS RMS; voice at −22 dBFS from 2 s | 0–2 s | 2–8 s | Noise reduction (test_denoise_fixtures) |
| `keyboard.wav` | Key clicks (double, decaying high-passed bursts) peaking at −12 dBFS every 90–250 ms; voice from 2 s | 0–2 s | 2–8 s | Noise reduction (test_denoise_fixtures) |
| `near_far_speech.wav` | Voice from 1 s, alternating near (−18 dBFS) and far (−16 dB quieter) every 1.5 s; room noise −55 dBFS | 0–1 s | 1–8 s | AGC level (test_agc) |
| `loud_laugh.wav` | Voice at −20 dBFS from 1 s, with 3–5 s boosted by 17 dB (near/over full scale) | 0–1 s | 1–8 s (loud 3–5 s) | Limiter, no sample above −1 dBFS (test_agc) |
| `silence_noise.wav` | Room noise only at −50 dBFS, no voice | 0–8 s | — | AGC must not raise gain on noise (test_agc) |

Tests skip the first 0.5 s of a noise-only range while DeepFilterNet
converges.
