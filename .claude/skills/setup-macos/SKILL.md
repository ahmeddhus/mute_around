---
name: setup-macos
description: Set up, build and run Mute Around on macOS after cloning. Use when someone asks to set up, install prerequisites for, build or run the app on a Mac, or when a first macOS build fails because a tool is missing.
user-invocable: true
---

# Set up Mute Around on macOS

Get a fresh clone building and running on macOS 13+ (Apple Silicon). The
README's "Build from source" section is the source of truth. If it disagrees
with this skill, follow the README and say so.

Work through the steps in order. Check each prerequisite before acting, and
report what was already there and what is missing. **Never run `sudo` or
install the HAL plug-in yourself.** Anything that needs an administrator
password is the user's to run.

## 1. Check the platform

```bash
sw_vers -productVersion && uname -m
```

The app needs macOS 13 or later on `arm64`. If either is wrong, stop and tell
the user.

## 2. Check prerequisites

Run these checks and collect the results in one table (tool, found version,
required, OK/missing):

| Tool | Check | Required | If missing, suggest |
|---|---|---|---|
| Xcode | `xcodebuild -version` | installed, first launch done | Install Xcode from the App Store, then `sudo xcodebuild -runFirstLaunch` (the user runs it) |
| Xcode CLT selected | `xcode-select -p` | points into `Xcode.app` | `sudo xcode-select -s /Applications/Xcode.app` (the user runs it) |
| Flutter | `flutter --version` | ≥ 3.50 stable | https://docs.flutter.dev/get-started/install/macos |
| Rust | `rustc --version` and `cargo --version` | stable ≥ 1.70 | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh`, or `rustup update stable` if it's too old |
| CMake | `cmake --version` | ≥ 3.24 | `brew install cmake` |

Also run `flutter doctor` and report only the problems that matter for the
macOS desktop target. Android, iOS, web and Chrome warnings don't matter.

Before installing anything, ask the user. List the exact commands and run
only the ones they approve. Homebrew and rustup installs don't need `sudo`.
Don't install Homebrew itself without asking.

## 3. Submodules

```bash
git submodule status
```

If any line starts with `-` (not initialised), run:

```bash
git submodule update --init --recursive
```

DeepFilterNet and libASPL come from these submodules, and the build fails
without them.

## 4. Dart dependencies and generated code

```bash
flutter pub get
dart run build_runner build -d
```

Generated files (`*.g.dart`, `*.freezed.dart`, `*.config.dart`) are not
committed, so this step is required on every fresh clone.

## 5. Run the app

```bash
flutter run -d macos
```

Run it in the background or in a terminal tab, because it keeps running. The
first build takes several minutes: `hook/build.dart` compiles the C engine
and DeepFilterNet with cargo, and an Xcode build phase builds
`MuteAround.driver`. If it fails, read the first real error, not the last
line:

- `cargo`/`rustc` not found → Rust isn't on `PATH` for this shell. Run
  `source "$HOME/.cargo/env"` and retry.
- CMake errors or a version that's too old → step 2.
- Missing files under `native/` third-party paths → step 3.
- `*.g.dart` / `*.freezed.dart` not found → step 4.
- Code-signing errors → the project builds unsigned for development. Report
  the error to the user. Don't add a signing identity, and never commit one.

## 6. First run (tell the user)

The setup screen asks for microphone access, then offers **Install Mute
Around microphone**. That step asks for the administrator password once: it
copies the plug-in to `/Library/Audio/Plug-Ins/HAL` and restarts Core Audio.
The user clicks it themselves. To install the plug-in by hand while
developing, the user can run `native/macos_hal/scripts/dev_install.sh` (it
uses `sudo`). To remove it, they can run
`native/macos_hal/scripts/dev_uninstall.sh`.

Then the user picks **Mute Around** as the microphone in Zoom, Slack, Teams,
Discord or OBS.

## 7. Optional: verify the dev setup

If the user is going to contribute, run the project's checks and report the
real results:

```bash
flutter analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
flutter test
cmake -S native/engine -B build/native-tests -DCMAKE_BUILD_TYPE=Release
cmake --build build/native-tests
ctest --test-dir build/native-tests --output-on-failure
```

## Finish

Summarise what was installed, what was already present, whether the app
launched, and anything left for the user (Xcode first launch, the
microphone-install click).
