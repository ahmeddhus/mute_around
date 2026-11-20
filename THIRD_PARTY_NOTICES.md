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
| Rust crates linked into libDF | see `native/engine/dfshim/Cargo.lock` | tract (ONNX inference), ndarray, rustfft, … | To be audited with `cargo deny` | crates.io |

The WAV fixtures in `native/engine/tests/fixtures/` are synthetic, generated
by this repository, and released under CC0 1.0.
