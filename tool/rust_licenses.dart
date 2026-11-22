// Collects the license texts of the Rust code linked into the engine
// into native/engine/third_party/rust_licenses.json, which the app
// shows on its licenses page (lib/app/licenses.dart):
//
//   dart tool/rust_licenses.dart          # regenerate after Cargo.lock changes
//   dart tool/rust_licenses.dart --check  # exit 1 if the file is out of date
//
// "Linked" means the crates reachable from the DeepFilterNet shim through
// normal (not build or dev) dependencies on each supported target, minus
// proc macros, which only run inside the compiler. The two local crates
// (our shim and libDF) are left out: lib/app/licenses.dart lists libDF with
// its own license files. The Rust standard library is linked too and gets a
// fixed entry.
//
// Needs cargo (rustup) and network access the first time, to download the
// crates' sources. Uses only dart: libraries, so CI can run it with a plain
// Dart SDK.
import 'dart:convert';
import 'dart:io';

/// The targets the app ships for.
const _targets = ['aarch64-apple-darwin', 'x86_64-pc-windows-msvc'];

/// Package label for the standard library entry.
const rustStdLabel = 'Rust standard library';

/// Rust's own LICENSE-MIT (rust-lang/rust); the standard library is
/// MIT OR Apache-2.0, and its COPYRIGHT file says contributors keep their
/// copyrights.
const _rustStdText = '''
Copyrights in the Rust project are retained by their contributors.

Permission is hereby granted, free of charge, to any
person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the
Software without restriction, including without
limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software
is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice
shall be included in all copies or substantial portions
of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.''';

/// The MIT terms, for a crate whose package has no license file. The
/// copyright line is built from the crate's authors.
const _mitTerms = '''
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''';

/// File names (upper-cased prefixes) that hold license or notice texts.
const _licenseFilePrefixes = [
  'LICENSE',
  'LICENCE',
  'COPYING',
  'COPYRIGHT',
  'UNLICENSE',
  'NOTICE',
];

/// The package label shown on the licenses page for crate [name].
String crateLabel(String name) => '$name (Rust crate)';

Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  final root = Directory.fromUri(Platform.script.resolve('..'));
  final manifest = File('${root.path}native/engine/dfshim/Cargo.toml');
  final output = File(
    '${root.path}native/engine/third_party/rust_licenses.json',
  );

  final crates = <String, _Crate>{};
  for (final target in _targets) {
    for (final crate in await _linkedCrates(manifest, target)) {
      crates[crate.id] = crate;
    }
  }
  final generated = _render(crates.values);

  if (check) {
    final current = output.existsSync()
        ? output.readAsStringSync().replaceAll('\r\n', '\n')
        : '';
    if (current != generated) {
      stderr.writeln(
        '${output.path} is out of date with Cargo.lock. '
        'Run `dart tool/rust_licenses.dart` and commit the result.',
      );
      exitCode = 1;
      return;
    }
    stdout.writeln('${output.path} is up to date (${crates.length} crates).');
    return;
  }
  output.writeAsStringSync(generated);
  stdout.writeln('Wrote ${output.path} (${crates.length} crates).');
}

/// One crate from `cargo metadata`.
class _Crate {
  _Crate(Map<String, Object?> package)
    : id = package['id']! as String,
      name = package['name']! as String,
      license = package['license'] as String?,
      authors = (package['authors']! as List<Object?>).cast<String>(),
      licenseFile = package['license_file'] as String?,
      dir = File(package['manifest_path']! as String).parent;

  final String id;
  final String name;
  final String? license;
  final List<String> authors;
  final String? licenseFile;
  final Directory dir;

  /// The crate's license and notice texts, one per file.
  List<String> texts() {
    final files = <String>{
      for (final entity in dir.listSync())
        if (entity is File && _isLicenseFile(_baseName(entity.path)))
          entity.path,
      if (licenseFile case final file?) '${dir.path}/$file',
    }.toList()..sort();
    if (files.isNotEmpty) {
      return [for (final f in files) _normalize(File(f).readAsStringSync())];
    }
    // Some crates (e.g. realfft) don't package their license file.
    if (license == 'MIT') {
      final holders = authors
          .map((a) => a.replaceAll(RegExp(r'\s*<[^>]*>'), '').trim())
          .join(', ');
      return ['Copyright (c) $holders\n\n$_mitTerms'];
    }
    throw StateError(
      'The crate $name ($license) ships no license file and has no fallback '
      'in tool/rust_licenses.dart. Add its license text by hand.',
    );
  }
}

bool _isLicenseFile(String name) {
  final upper = name.toUpperCase();
  return _licenseFilePrefixes.any(upper.startsWith);
}

String _baseName(String path) => path.split(RegExp(r'[/\\]')).last;

String _normalize(String text) => text.replaceAll('\r\n', '\n').trimRight();

/// The crates linked into the engine on [target].
Future<List<_Crate>> _linkedCrates(File manifest, String target) async {
  final cargo = _findCargo();
  final result = await Process.run(
    cargo,
    [
      'metadata',
      '--format-version',
      '1',
      '--locked',
      '--manifest-path',
      manifest.path,
      '--filter-platform',
      target,
    ],
    environment: {
      // A rustup proxy needs its toolchain's rustc on PATH.
      'PATH': [
        File(cargo).parent.path,
        Platform.environment['PATH'] ?? '',
      ].join(Platform.isWindows ? ';' : ':'),
    },
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      cargo,
      const ['metadata'],
      '${result.stderr}',
      result.exitCode,
    );
  }
  final metadata = jsonDecode(result.stdout as String) as Map<String, Object?>;
  final packages = {
    for (final p
        in (metadata['packages']! as List<Object?>)
            .cast<Map<String, Object?>>())
      p['id']! as String: p,
  };
  final resolve = metadata['resolve']! as Map<String, Object?>;
  final nodes = {
    for (final n
        in (resolve['nodes']! as List<Object?>).cast<Map<String, Object?>>())
      n['id']! as String: n,
  };

  bool isProcMacro(Map<String, Object?> package) =>
      (package['targets']! as List<Object?>).cast<Map<String, Object?>>().any(
        (t) => (t['kind']! as List<Object?>).contains('proc-macro'),
      );

  final linked = <String>{};
  final pending = [resolve['root']! as String];
  while (pending.isNotEmpty) {
    final id = pending.removeLast();
    if (linked.contains(id) || isProcMacro(packages[id]!)) continue;
    linked.add(id);
    final deps = (nodes[id]!['deps']! as List<Object?>)
        .cast<Map<String, Object?>>();
    for (final dep in deps) {
      final kinds = (dep['dep_kinds']! as List<Object?>)
          .cast<Map<String, Object?>>();
      // `kind: null` is a normal dependency; build/dev ones aren't linked.
      if (kinds.any((k) => k['kind'] == null)) {
        pending.add(dep['pkg']! as String);
      }
    }
  }
  return [
    for (final id in linked)
      // `source: null` is a local path crate: our shim and libDF.
      if (packages[id]!['source'] != null) _Crate(packages[id]!),
  ];
}

/// One entry per distinct license text, naming every crate that ships it,
/// so the many identical Apache-2.0 texts appear once.
String _render(Iterable<_Crate> crates) {
  final byText = <String, Set<String>>{
    _rustStdText: {rustStdLabel},
  };
  for (final crate in crates) {
    for (final text in crate.texts()) {
      (byText[text] ??= {}).add(crateLabel(crate.name));
    }
  }
  final entries = [
    for (final MapEntry(key: text, value: labels) in byText.entries)
      {'packages': labels.toList()..sort(), 'text': text},
  ]..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
  const encoder = JsonEncoder.withIndent('  ');
  return '${encoder.convert({
    'comment': 'Generated by tool/rust_licenses.dart from '
        'native/engine/dfshim/Cargo.lock. Do not edit.',
    'targets': _targets,
    'entries': entries,
  })}\n';
}

String _sortKey(Map<String, Object> entry) =>
    '${(entry['packages']! as List<String>).join(',')}\n${entry['text']}';

String _findCargo() {
  final exe = Platform.isWindows ? 'cargo.exe' : 'cargo';
  final home =
      Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'] ?? '';
  final candidates = [
    ...?Platform.environment['PATH']?.split(Platform.isWindows ? ';' : ':'),
    '$home/.cargo/bin',
    // Homebrew's rustup is keg-only and not on PATH by default.
    '/opt/homebrew/opt/rustup/bin',
    '/usr/local/opt/rustup/bin',
  ];
  for (final dir in candidates) {
    final file = File('$dir${Platform.pathSeparator}$exe');
    if (file.existsSync()) return file.path;
  }
  throw StateError('cargo not found. Install Rust from https://rustup.rs.');
}
