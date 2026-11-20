# Third-Party Notices

Mute Around uses open-source components. Only permissive licenses (MIT, BSD,
Apache-2.0, zlib) are allowed — see `CLAUDE.md`.

## Dart / Flutter packages

Not listed here. Their exact versions are pinned in `pubspec.lock`, and Flutter
bundles their license texts automatically into the app's licenses page
(`showLicensePage`). Check a package's license on pub.dev before adding it.

## Native libraries and model files

Flutter does not collect these automatically. Each entry MUST also be
registered in the app with `LicenseRegistry.addLicense` so it appears on the
licenses page, and its license text MUST ship with the app.

| Component | Used for | License | Status |
|---|---|---|---|
| DeepFilterNet 3 (code) | Noise suppression engine | MIT / Apache-2.0 | Planned |
| DeepFilterNet 3 (model weights) | Trained model | To verify before bundling | Planned |
