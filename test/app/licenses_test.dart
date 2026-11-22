import 'dart:convert';
import 'dart:io';

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
        'Rust standard library',
        'tract-core (Rust crate)',
        'rustfft (Rust crate)',
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

  group('Rust crate licenses', () {
    // The committed asset, as the app bundles it.
    final json = File(rustLicensesAsset).readAsStringSync();
    final raw =
        ((jsonDecode(json) as Map<String, Object?>)['entries']!
                as List<Object?>)
            .cast<Map<String, Object?>>();

    test('covers both shipped targets', () {
      final targets = (jsonDecode(json) as Map<String, Object?>)['targets'];
      expect(targets, ['aarch64-apple-darwin', 'x86_64-pc-windows-msvc']);
    });

    test('yields one entry per text, with every crate named', () {
      final entries = rustLicenseEntries(json).toList();
      expect(entries, hasLength(raw.length));
      final packages = entries.expand((e) => e.packages).toSet();
      // tract and rustfft on both platforms; libc only on macOS and
      // windows-sys only on Windows (union of the targets).
      expect(
        packages,
        containsAll([
          'tract-onnx (Rust crate)',
          'libc (Rust crate)',
          'windows-sys (Rust crate)',
          'realfft (Rust crate)',
        ]),
      );
      // Proc macros and their build-time dependencies aren't linked.
      expect(packages, isNot(contains('unicode-ident (Rust crate)')));
      expect(packages, isNot(contains('derive-new (Rust crate)')));
    });

    test('every entry has a non-empty text and at least one package', () {
      for (final entry in rustLicenseEntries(json)) {
        expect(entry.packages, isNotEmpty);
        expect(entry.paragraphs.map((p) => p.text).join(), isNotEmpty);
      }
    });

    test('a crate without a license file gets its MIT text', () {
      final realfft = rustLicenseEntries(
        json,
      ).firstWhere((e) => e.packages.contains('realfft (Rust crate)'));
      final text = realfft.paragraphs.map((p) => p.text).join(' ');
      expect(text, contains('Copyright (c) HEnquist'));
      expect(text, contains('Permission is hereby granted'));
    });
  });
}
