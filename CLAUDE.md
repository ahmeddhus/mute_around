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
dart run build_runner build -d         # generate code (or `watch -d`)
flutter analyze --fatal-infos          # must be clean
dart format .                          # must produce no changes
flutter test                           # all tests pass
flutter run -d macos                   # or -d windows
```

Before saying work is done: run build_runner, analyze, format and test, and
report the real results.

## Architecture

Clean Architecture, feature-first, with BLoC for state, GoRouter (typed
routes) for navigation, and get_it + injectable for dependency injection.
Follows the Flutter team's architecture guide (layers, unidirectional data
flow, `Result` errors, immutable models, fakes in tests) with Clean
Architecture's domain layer.

```
lib/
  main.dart                 # bootstrap only: configureDependencies(), runApp
  app/
    app.dart                # MaterialApp.router, theme
    router.dart             # typed GoRouter routes (+ router.g.dart)
    di.dart                 # @InjectableInit composition root (+ di.config.dart)
  core/
    result.dart             # sealed Result<T> = Ok | Err
    failures.dart           # sealed Failure hierarchy
    native/                 # FFI: ffigen bindings (*.ffigen.dart) + loader
  features/<feature>/
    domain/
      entities/             # pure Dart, immutable (@freezed)
      repositories/         # abstract interfaces
      usecases/             # one public `call()` each
    data/
      datasources/          # FFI engine, OS APIs, local storage
      models/               # DTOs (@freezed + json_serializable) + mappers
      repositories/         # implementations of domain interfaces
    presentation/
      bloc/                 # <name>_bloc.dart, _event.dart, _state.dart
      pages/                # routed screens
      widgets/              # feature-private widgets
native/                     # C/C++ real-time engine, ONE C header ABI
native/macos_hal/           # Core Audio HAL plug-in (virtual mic)
```

Windows v1 outputs to VB-CABLE; no kernel driver.

### Dependency rule (enforced in review)
- `domain/` imports **only** Dart core, `freezed_annotation`, `injectable`
  annotations and `core/` — no Flutter, no `data/`, no `presentation/`, no FFI.
- `data/` imports `domain/` and `core/`. It is the only layer that touches
  FFI, OS APIs or storage.
- `presentation/` imports `domain/` (use cases, entities) — never `data/`.
- Features never import each other's `data/` or `presentation/`; share through
  `core/` or a domain interface.
- Only DI (annotations + `app/di.dart`) wires concrete implementations to
  interfaces.

### BLoC
- Use `Bloc` for event-driven flows (engine start/stop, device changes);
  `Cubit` for simple UI state (settings toggles).
- Events and states are `@freezed` sealed unions (value equality, `copyWith`).
  Prefer one state class with a status enum when fields are shared; handle
  them with Dart `switch`, not freezed's `when`/`map`.
- Blocs depend on use cases only, never on `BuildContext`, widgets, other
  blocs, or `data/` classes. React to other features via repository streams.
- Provide blocs with `BlocProvider` at the route that owns them; read with
  `context.read`/`select`, build with `BlocBuilder`/`BlocSelector`, side
  effects with `BlocListener`.
- High-rate data (audio level meters) is throttled to ≤ 30 updates/s before
  it reaches a bloc; never emit per audio buffer.
- Always close streams/subscriptions in `close()`.

### Navigation (GoRouter + go_router_builder)
- Typed routes only: `@TypedGoRoute` classes extending `GoRouteData` in
  `app/router.dart`. Navigate with `const SettingsRoute().go(context)`, never
  raw path strings.
- Redirects handle first-run setup (e.g. VB-CABLE / HAL plug-in missing).

### Dependency injection (get_it + injectable)
- Annotate, don't register by hand: `@LazySingleton(as: Interface)` for
  datasources and repositories, `@injectable` (factory) for use cases and
  blocs, `@module` for third-party objects.
- `configureDependencies()` in `app/di.dart` is called once in `main.dart`.
- Widgets get blocs from `BlocProvider(create: (_) => getIt<XBloc>())`; never
  call `getIt` inside blocs, use cases or domain code (use constructor injection).
- Use `@Environment` (e.g. `test`) for fakes when needed.

### Code generation
- Tools: `build_runner` with `freezed`, `json_serializable`,
  `go_router_builder` and `injectable_generator`, scoped in `build.yaml`.
- Generated files (`*.g.dart`, `*.freezed.dart`, `*.config.dart`) are **not
  committed**; run `dart run build_runner build -d` after cloning and after
  changing annotated code. Never edit generated files.
- FFI bindings are generated with `ffigen` (Dart API config in
  `tool/ffigen.dart`, not the deprecated YAML) into `*.ffigen.dart`. These ARE
  committed, so contributors don't need LLVM installed.
- Native libraries are built and bundled with Dart build hooks
  (`hook/build.dart`, native assets), not hand-written CMake/Xcode steps,
  where possible.

### Errors
- Repositories and use cases return `Result<T>` (`Ok` / `Err(Failure)`);
  they don't throw across layers. Use `switch` on the sealed type.
- Catch native/OS errors at the `data/` boundary and map them to `Failure`s.

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
- Only MIT/MIT-0/BSD/Apache-2.0/zlib/ISC/Unicode-3.0 (or public-domain)
  dependencies. Check the license before adding
  any package or native library. Native libraries and model files must be
  recorded in `THIRD_PARTY_NOTICES.md` and registered with
  `LicenseRegistry.addLicense`; Dart packages are covered automatically.
- Never commit secrets, signing identities or personal data.

### Testing
- Dart: unit tests for use cases and repositories (with fakes/mocktail mocks of
  the layer below), `bloc_test` for every bloc/cubit, widget tests for pages
  (with mocked blocs), and tests for the FFI datasource lifecycle
  (init/start/stop/dispose) and error paths.
- Native DSP: tests driven by offline WAV fixtures (noisy in → measure out).
- Tests live in `test/` mirroring `lib/`.

### Workflow
- Work on a branch, never directly on `master`. Small, descriptive commits
  (Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `test:`).
- Platforms: macOS and Windows only — don't add Linux/mobile/web code.
