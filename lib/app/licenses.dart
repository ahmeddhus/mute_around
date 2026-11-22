import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A native library or model file whose license Flutter doesn't collect on
/// its own (Dart packages are covered automatically).
typedef NativeLicense = ({List<String> packages, String asset});

/// Every native component shipped with the app (THIRD_PARTY_NOTICES.md).
const nativeLicenses = <NativeLicense>[
  (
    packages: ['miniaudio'],
    asset: 'native/engine/third_party/miniaudio/LICENSE',
  ),
  (
    packages: ['DeepFilterNet (libDF)'],
    asset: 'native/engine/third_party/deepfilternet/LICENSE-MIT',
  ),
  (
    packages: ['DeepFilterNet (libDF)'],
    asset: 'native/engine/third_party/deepfilternet/LICENSE-APACHE',
  ),
  (
    packages: ['DeepFilterNet 3 model weights'],
    asset: 'native/engine/models/LICENSE-MIT',
  ),
  (
    packages: ['libASPL'],
    asset: 'native/macos_hal/third_party/libASPL/LICENSE',
  ),
];

/// Adds the native licenses to the app's licenses page (`showLicensePage`).
/// Call once at startup; the texts load lazily when the page opens.
void registerNativeLicenses({AssetBundle? bundle}) {
  final assets = bundle ?? rootBundle;
  LicenseRegistry.addLicense(() async* {
    for (final (:packages, :asset) in nativeLicenses) {
      yield LicenseEntryWithLineBreaks(
        packages,
        await assets.loadString(asset),
      );
    }
  });
}
