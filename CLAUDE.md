# Mute Around

Desktop app (macOS + Windows) that removes background noise and improves voice
quality in real time, exposing the cleaned audio to Zoom/Slack/Teams/Discord/OBS
through a virtual microphone. Public open-source repo — write code you'd be
happy to show.

**This file is the source of truth** for the project's rules. If a request
conflicts with it, say so instead of silently deviating.

## Commands

```bash
flutter pub get
flutter analyze --fatal-infos          # must be clean
dart format .                          # must produce no changes
flutter test                           # all tests pass
flutter run -d macos                   # or -d windows
```

Before saying work is done: run analyze, format and test, and report the
real results.

## Architecture (target)

- `lib/` — Flutter UI and app logic (Dart). Everything that is not real-time
  audio or an OS driver lives here.
- `lib/src/native/` — the Dart side of the FFI boundary (bindings + thin,
  idiomatic Dart wrappers). Generated bindings end in `.g.dart`.
- `native/` — C/C++ real-time audio engine (capture → DeepFilterNet 3 → AGC →
  output) exposing **one** C header as its ABI.
- `native/macos_hal/` — Core Audio HAL plug-in (virtual microphone).
- Windows v1 outputs to VB-CABLE; no kernel driver.

## Rules

### Flutter / Dart
- Flutter-first: only write native code for the audio thread or OS drivers,
  and justify it in the plan.
- Use the latest stable Flutter (3.50+) and Dart features: dot shorthands
  (`.center`, `.fromSeed(...)`), records, patterns, sealed classes,
  `switch` expressions.
- This project imports Material from `package:material_ui/material_ui.dart`
  (Flutter 3.50 decoupled design libraries); don't use `package:flutter/material.dart`.
- Package imports only (`package:mute_around/...`), never relative imports.
- Prefer `final`, `const` constructors, small widgets over helper methods
  returning widgets, and immutable state.
- Never ignore a lint without a comment explaining why
  (`// ignore: rule_name — reason`).
- No `print`; use `dart:developer` `log` or a logger.
- Await or explicitly `unawaited(...)` every `Future`.

### FFI / native
- The C ABI is small, versioned, and documented in its header. Plain C types
  only across the boundary (no C++ types, no exceptions crossing it).
- Native code owns its memory; Dart must call explicit `*_destroy` functions
  (wrap them with `NativeFinalizer` as a safety net).
- **Audio thread rules (non-negotiable):** no allocation, no locks, no I/O, no
  logging, no calls into Dart. Use lock-free SPSC ring buffers / atomics to
  talk to the UI.
- Latency budget: ≤ 50 ms end to end. Mention latency/CPU impact of any DSP change.
- C/C++ formatted with `.clang-format`.

### Privacy & licensing
- No network calls, telemetry, analytics or accounts. Ever.
- Never write audio to disk unless the user explicitly asks.
- Only MIT/BSD/Apache-2.0/zlib dependencies. Check the license before adding
  any package or native library and record it in `THIRD_PARTY_NOTICES`.
- Never commit secrets, signing identities or personal data.

### Testing
- Dart: unit tests for logic, widget tests for UI, tests for the FFI wrapper
  lifecycle (init/start/stop/dispose) and error paths.
- Native DSP: tests driven by offline WAV fixtures (noisy in → measure out).
- Tests live in `test/` mirroring `lib/`.

### Workflow
- Work on a branch, never directly on `master`. Small, descriptive commits
  (Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `test:`).
- Platforms: macOS and Windows only — don't add Linux/mobile/web code.
