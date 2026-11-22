import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mute_around/app/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registers every native component with its bundled text', () async {
    registerNativeLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final packages = entries.expand((e) => e.packages).toSet();
    expect(
      packages,
      containsAll([
        'miniaudio',
        'DeepFilterNet (libDF)',
        'DeepFilterNet 3 model weights',
        'libASPL',
      ]),
    );
    final miniaudio = entries.firstWhere(
      (e) => e.packages.contains('miniaudio'),
    );
    expect(
      miniaudio.paragraphs.map((p) => p.text).join(' '),
      contains('MIT'),
    );
  });
}
