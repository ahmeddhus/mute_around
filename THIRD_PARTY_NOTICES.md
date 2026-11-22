# Third-Party Notices

Mute Around uses open-source components. Only permissive licenses (MIT,
MIT-0, BSD, Apache-2.0, zlib, ISC, Unicode-3.0, public domain) are allowed —
see `CLAUDE.md`.

## Dart / Flutter packages

Not listed here. Their exact versions are pinned in `pubspec.lock`, and Flutter
bundles their license texts automatically into the app's licenses page
(`showLicensePage`). Check a package's license on pub.dev before adding it.

## Native libraries and model files

Flutter does not collect these automatically. Each entry MUST also be
registered in the app with `LicenseRegistry.addLicense` so it appears on the
licenses page, and its license text MUST ship with the app.

| Component | Version | Used for | License | Where |
|---|---|---|---|---|
| DeepFilterNet 3 / libDF (code) | v0.5.6 | Noise suppression engine | MIT / Apache-2.0 | `native/engine/third_party/deepfilternet` (submodule) |
| DeepFilterNet 3 low-latency model weights | v0.5.6 | Trained model, embedded in the engine | MIT / Apache-2.0 | `models/DeepFilterNet3_ll_onnx.tar.gz` in the submodule |
| miniaudio | 0.11.26 | Audio capture/playback (Core Audio, WASAPI) | Public domain (Unlicense) or MIT-0 | `native/engine/third_party/miniaudio` |
| libASPL | v3.1.2 | macOS Audio Server plug-in (virtual mic) | MIT (parts derived from Apple sample code, also under MIT terms) | `native/macos_hal/third_party/libASPL` (submodule) |
| dr_wav (tests only, not shipped) | 0.14.6 | Reading WAV fixtures | Public domain (Unlicense) or MIT-0 | `native/engine/tests/third_party/dr_wav.h` |
| Rust crates linked into libDF | see `native/engine/dfshim/Cargo.lock` | tract (ONNX inference), ndarray, rustfft, … | MIT, Apache-2.0, Zlib, Unlicense, 0BSD (see below) | crates.io |
| Rust standard library | the Rust toolchain used to build | Linked into the engine with the crates | MIT / Apache-2.0 | rustup |

### Rust dependency audit

`native/engine/third_party/deny.toml` allows only the project's
licenses; check with `cargo deny` (command in that file).

Audited 2026-11-21 from `cargo tree` for `aarch64-apple-darwin` (169
crates): every crate is MIT, Apache-2.0, MIT OR Apache-2.0, a
Zlib/MIT/Apache choice, Unlicense OR MIT, or 0BSD OR MIT OR Apache-2.0,
except two used only while compiling (by proc macros), which are neither
linked nor shipped:

- `tiny-keccak` — CC0-1.0 (a public-domain dedication), via
  `const-random-macro`.
- `unicode-ident` — (MIT OR Apache-2.0) AND Unicode-DFS-2016, via
  `proc-macro2`; listed as an exception in `deny.toml`.

`cargo deny check licenses` passed on 2026-11-22 for both
`aarch64-apple-darwin` and `x86_64-pc-windows-msvc`, so the Windows-only
crates (e.g. `winapi`) are covered too. CI re-runs it on every pull request
(the "Rust dependency licenses" job in `.github/workflows/ci.yml`).

Attribution: MIT and Apache-2.0 require keeping each copyright and license
notice. `tool/rust_licenses.dart` collects the license and notice files of
every crate linked into the engine, on both targets, plus the Rust standard
library, into `native/engine/third_party/rust_licenses.json`. That file is
bundled with the app and registered in `lib/app/licenses.dart`, so every
crate appears on the licenses page. "Linked" means reachable through normal
dependencies (not build or dev ones), minus proc macros, so 84 crates
rather than the 169 that `cargo tree` lists. `realfft` packages no license
file, so its MIT text is built from its declared author.

Regenerate the file after changing `Cargo.lock`:

```bash
dart tool/rust_licenses.dart
```

CI runs `dart tool/rust_licenses.dart --check` and fails if it's out of date.

## Tray icons

`assets/tray/` icons are drawn by `tool/make_tray_icons.dart` from simple
shapes, in this repository; CC0 1.0.

The WAV fixtures in `native/engine/tests/fixtures/` are synthetic, generated
by this repository, and released under CC0 1.0.
