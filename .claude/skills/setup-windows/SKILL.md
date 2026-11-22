---
name: setup-windows
description: Set up, build and run Mute Around on Windows after cloning. Use when someone asks to set up, install prerequisites for, build or run the app on Windows, or when a first Windows build fails because a tool or VB-CABLE is missing.
user-invocable: true
---

# Set up Mute Around on Windows

Get a fresh clone building and running on Windows 10/11 x64. The README's
"Build from source" section is the source of truth. If it disagrees with this
skill, follow the README and say so.

Work through the steps in order. Check each prerequisite before acting, and
report what was already there and what is missing. Commands below are
PowerShell. **Never run an installer elevated or install VB-CABLE yourself.**
Anything that needs administrator rights is the user's to run.

## 1. Check the platform

```powershell
[System.Environment]::OSVersion.Version; $env:PROCESSOR_ARCHITECTURE
```

The app needs Windows 10 or 11 on `AMD64`. If either is wrong, stop and tell
the user.

## 2. Check prerequisites

Run these checks and collect the results in one table (tool, found version,
required, OK/missing):

| Tool | Check | Required | If missing, suggest |
|---|---|---|---|
| Git | `git --version` | any | `winget install --id Git.Git -e` |
| Visual Studio 2022 C++ | `& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -version "[17.0,18.0)" -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property displayName` | prints a VS 2022 product | `winget install --id Microsoft.VisualStudio.2022.BuildTools -e --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"` (the user approves the UAC prompt) |
| Flutter | `flutter --version` | ≥ 3.50 stable | https://docs.flutter.dev/get-started/install/windows/desktop |
| Rust | `rustc --version`, `cargo --version`, `rustup show active-toolchain` | stable ≥ 1.70, `x86_64-pc-windows-msvc` | `winget install --id Rustlang.Rustup -e`, then `rustup default stable-msvc` |
| CMake | `cmake --version` | ≥ 3.24 | `winget install --id Kitware.CMake -e` (VS 2022's bundled CMake also works) |

Also run `flutter doctor` and report only the problems that matter for the
Windows desktop target. Android, web and Chrome warnings don't matter. If
Rust's active toolchain is `-gnu`, the build won't link against MSVC, so
suggest `rustup default stable-msvc`.

Before installing anything, ask the user. List the exact commands and run
only the ones they approve. After an install, a new terminal may be needed
before the tool shows up on `PATH`. Say so instead of editing `PATH` by hand.

Also check that Developer Mode is on, because Flutter needs symlink support
for plugins. If `flutter pub get` complains about symlinks, tell the user to
turn it on with `start ms-settings:developers`. It's a system setting, so the
user changes it.

## 3. Submodules

```powershell
git submodule status
```

If any line starts with `-` (not initialised), run:

```powershell
git submodule update --init --recursive
```

The DeepFilterNet submodule is required, and the build fails without it.
(libASPL is macOS-only, but initialise everything anyway.)

## 4. Dart dependencies and generated code

```powershell
flutter pub get
dart run build_runner build -d
```

Generated files (`*.g.dart`, `*.freezed.dart`, `*.config.dart`) are not
committed, so this step is required on every fresh clone.

## 5. VB-CABLE (virtual microphone)

On Windows v1, Mute Around plays into the free VB-CABLE driver. There is no
kernel driver of its own. Check whether it's installed:

```powershell
Get-CimInstance Win32_SoundDevice | Where-Object Name -like '*VB-Audio*' | Select-Object Name
```

If nothing is listed, tell the user to download it from
https://vb-audio.com/Cable/, extract the zip, run `VBCABLE_Setup_x64.exe` **as
administrator**, and restart if asked. Don't download or run it for them. The
app also detects VB-CABLE by itself and shows a **Check again** button on its
setup screen, so this can be done after the first launch.

## 6. Run the app

```powershell
flutter run -d windows
```

Run it in the background or in a terminal tab, because it keeps running. The
first build takes several minutes: `hook/build.dart` compiles the C engine
and DeepFilterNet with cargo. If it fails, read the first real error, not the
last line:

- `cargo`/`rustc` not found → open a new terminal after installing rustup.
- MSVC linker (`link.exe`) or `cl.exe` not found → the VS 2022 C++ workload
  is missing (step 2).
- CMake version errors → step 2.
- Missing DeepFilterNet sources → step 3.
- `*.g.dart` / `*.freezed.dart` not found → step 4.

## 7. First run (tell the user)

- If Windows blocks the microphone, the user allows desktop apps under
  **Settings → Privacy & security → Microphone**.
- In Zoom, Slack, Teams, Discord or OBS, the user picks **CABLE Output** as
  the microphone.

## 8. Optional: verify the dev setup

If the user is going to contribute, run the project's checks and report the
real results:

```powershell
flutter analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
flutter test
cmake -S native/engine -B build/native-tests -DCMAKE_BUILD_TYPE=Release
cmake --build build/native-tests --config Release
ctest --test-dir build/native-tests -C Release --output-on-failure
```

## Finish

Summarise what was installed, what was already present, whether the app
launched, and anything left for the user (the VB-CABLE install, Developer
Mode, microphone privacy).
