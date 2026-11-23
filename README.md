# Mute Around

Removes background noise from your microphone and keeps your voice at a
steady volume, in real time, on macOS and Windows. Zoom, Slack, Teams,
Discord, OBS and any other app hear the cleaned-up voice through a virtual
microphone.

- **Noise suppression** with [DeepFilterNet 3](https://github.com/Rikorose/DeepFilterNet)
  (low-latency model): fans, air conditioning, hum, keyboard clicks, street
  noise. Three strengths: Low, Medium, High.
- **Auto gain**: speech-gated level control plus a limiter, so you're never
  too quiet and never clip.
- **Instant bypass** to hear your raw mic, without the meeting app losing
  its microphone. If the computer gets too busy, Mute Around switches to
  raw audio by itself instead of crackling, and resumes when it can.
- **Live meters** for the input and the cleaned output.
- **Runs in the background** from the menu bar (macOS) or the system tray
  (Windows).
- **Private**: everything runs on your computer. No network, no accounts,
  no telemetry, nothing recorded.

Adds at most ~50 ms of delay. Supported: macOS 13+ on Apple Silicon, and
Windows 10/11 on x64.

## How it works

```
microphone → noise suppression (DeepFilterNet 3) → auto gain → limiter → virtual mic → meeting app
```

- **macOS:** Mute Around installs its own virtual microphone, called
  **Mute Around** (a Core Audio plug-in). Pick it as the microphone in your
  meeting app.
- **Windows:** Mute Around plays into the free
  [VB-CABLE](https://vb-audio.com/Cable/) virtual cable. Pick
  **CABLE Output** as the microphone in your meeting app.

The app is Flutter. The real-time audio engine is a small C library
(miniaudio + DeepFilterNet's Rust core) behind one C header
(`native/engine/include/mute_engine.h`), called through `dart:ffi`.

## Build from source

Signed installers aren't available yet; build it yourself.

### Prerequisites

| Tool | macOS (Apple Silicon) | Windows 10/11 x64 |
|---|---|---|
| Flutter | 3.50+ stable | 3.50+ stable |
| Rust | stable ≥ 1.70 via [rustup](https://rustup.rs) | stable ≥ 1.70, MSVC toolchain |
| C/C++ toolchain | Xcode + Command Line Tools | Visual Studio 2022 Build Tools (C++) |
| CMake | ≥ 3.24 (`brew install cmake`) | ≥ 3.24 |
| Virtual mic | built by this repo | [VB-CABLE](https://vb-audio.com/Cable/) |

### Steps

```bash
git clone --recurse-submodules https://github.com/ahmeddhus/mute_around.git
cd mute_around
flutter pub get
dart run build_runner build -d
flutter run -d macos        # or: flutter run -d windows
```

Already cloned without submodules? Run
`git submodule update --init --recursive`.

Using [Claude Code](https://claude.com/claude-code)? Run `/setup-macos` or
`/setup-windows`. Each one checks the prerequisites, suggests what to install
and then builds and runs the app. The skills are in `.claude/skills/`.

The first build takes a few minutes: the Dart build hook (`hook/build.dart`)
compiles the engine and DeepFilterNet with cargo. On macOS an Xcode build
phase also builds the `MuteAround.driver` plug-in into the app bundle.

### First run

- **macOS:** the setup screen asks for microphone access, then offers
  **Install Mute Around microphone**. This asks for your administrator
  password once: it copies the plug-in to `/Library/Audio/Plug-Ins/HAL` and
  restarts Core Audio.
- **Windows:** install [VB-CABLE](https://vb-audio.com/Cable/) (run its
  installer as administrator and restart if asked). Mute Around detects it
  by itself; you can also press **Check again**. If Windows blocks the
  microphone, allow desktop apps under Settings → Privacy → Microphone.

Processing starts automatically. Then pick **Mute Around** (macOS) or
**CABLE Output** (Windows) as the microphone in your meeting app.

## Uninstall the macOS virtual microphone

```bash
sudo rm -rf /Library/Audio/Plug-Ins/HAL/MuteAround.driver
sudo killall -9 coreaudiod
```

Or run `native/macos_hal/scripts/dev_uninstall.sh`. Core Audio restarts and
the "Mute Around" device disappears.

## Development

```bash
dart run build_runner build -d      # generated code (not committed)
flutter analyze --fatal-infos
dart format .
flutter test

# Native engine tests (unit + WAV fixtures + zero-allocation check)
cmake -S native/engine -B build/native-tests -DCMAKE_BUILD_TYPE=Release
cmake --build build/native-tests
ctest --test-dir build/native-tests --output-on-failure
```

- Regenerate the FFI bindings after changing `mute_engine.h` (needs LLVM;
  Xcode's on macOS): `dart run tool/ffigen.dart`. The macOS permission
  bindings come from `dart run tool/ffigen_avfoundation.dart`. Both outputs
  are committed.
- Install the macOS plug-in by hand while developing:
  `native/macos_hal/scripts/dev_install.sh`.
- The project's rules are in [`CLAUDE.md`](CLAUDE.md).

## License

Mute Around is released under the [MIT License](LICENSE).

## Third-party licenses

Third-party components and their licenses are listed in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md); only permissive licenses
are used. The app also shows them under About → Open-source licenses.
