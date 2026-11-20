// Build hook: compiles the native audio engine into the code asset
// `package:mute_around/mute_engine` (libmute_engine.dylib / mute_engine.dll).
//
// 1. Builds the DeepFilterNet shim (`native/engine/dfshim`, Rust) with cargo
//    into a static library.
// 2. Compiles the engine's C sources and miniaudio with native_toolchain_c,
//    linking the shim statically.
//
// Requires Rust (stable ≥ 1.70) and a C toolchain; see README.md.
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

const _engineSources = [
  'native/engine/src/engine.c',
  'native/engine/src/devices.c',
  'native/engine/src/processing.c',
  'native/engine/src/drift.c',
  'native/engine/src/ring_buffer.c',
  'native/engine/src/rt_thread.c',
  'native/engine/src/miniaudio_impl.c',
];

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;
    final root = input.packageRoot;

    final rustTarget = _rustTarget(code.targetOS, code.targetArchitecture);
    final cargoDir = input.outputDirectoryShared.resolve('cargo/');
    final rustLibDir = cargoDir.resolve('$rustTarget/release/');
    await _cargoBuild(
      manifest: root.resolve('native/engine/dfshim/Cargo.toml'),
      targetDir: cargoDir,
      rustTarget: rustTarget,
      macosDeploymentTarget: code.targetOS == OS.macOS
          ? '${code.macOS.deploymentVersion.major}.0'
          : null,
    );

    final (frameworks, libraries) = switch (code.targetOS) {
      OS.macOS => (
        ['CoreAudio', 'AudioToolbox', 'CoreFoundation', 'Security'],
        ['mute_df'],
      ),
      OS.windows => (
        const <String>[],
        // ole32 + avrt for WASAPI/MMCSS; the rest are Rust std dependencies.
        [
          'mute_df',
          'ole32',
          'avrt',
          'ws2_32',
          'userenv',
          'ntdll',
          'bcrypt',
          'advapi32',
        ],
      ),
      _ => throw UnsupportedError(
        'Mute Around supports macOS and Windows only',
      ),
    };

    await CBuilder.library(
      name: 'mute_engine',
      assetName: 'mute_engine',
      sources: _engineSources,
      includes: [
        'native/engine/include',
        'native/engine/src',
        'native/engine/third_party/miniaudio',
      ],
      frameworks: frameworks,
      libraries: libraries,
      libraryDirectories: [rustLibDir.toFilePath()],
      std: 'c11',
    ).run(input: input, output: output);

    output.dependencies.addAll([
      for (final dir in [
        'native/engine/src/',
        'native/engine/include/',
        'native/engine/dfshim/src/',
      ])
        ...Directory.fromUri(root.resolve(dir))
            .listSync()
            .whereType<File>()
            .map((f) => f.uri),
      root.resolve('native/engine/dfshim/Cargo.toml'),
      root.resolve('native/engine/dfshim/Cargo.lock'),
      root.resolve('native/engine/third_party/miniaudio/miniaudio.h'),
    ]);
  });
}

String _rustTarget(OS os, Architecture arch) => switch ((os, arch)) {
  (OS.macOS, Architecture.arm64) => 'aarch64-apple-darwin',
  (OS.macOS, Architecture.x64) => 'x86_64-apple-darwin',
  (OS.windows, Architecture.x64) => 'x86_64-pc-windows-msvc',
  (OS.windows, Architecture.arm64) => 'aarch64-pc-windows-msvc',
  _ => throw UnsupportedError('No Rust target for $os/$arch'),
};

Future<void> _cargoBuild({
  required Uri manifest,
  required Uri targetDir,
  required String rustTarget,
  String? macosDeploymentTarget,
}) async {
  final cargo = _findCargo();
  final env = <String, String>{
    // cargo needs rustc from the same toolchain folder on PATH.
    'PATH': [
      File(cargo).parent.path,
      Platform.environment['PATH'] ?? '',
    ].join(Platform.isWindows ? ';' : ':'),
    'MACOSX_DEPLOYMENT_TARGET': ?macosDeploymentTarget,
  };
  final result = await Process.run(cargo, [
    'build',
    '--release',
    '--locked',
    '--manifest-path',
    manifest.toFilePath(),
    '--target',
    rustTarget,
    '--target-dir',
    targetDir.toFilePath(),
  ], environment: env);
  if (result.exitCode != 0) {
    throw ProcessException(
      cargo,
      const ['build'],
      'Building the DeepFilterNet shim failed. Is the Rust target '
      '"$rustTarget" installed (rustup target add $rustTarget)?\n${result.stderr}',
      result.exitCode,
    );
  }
}

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
  throw StateError(
    'cargo not found. Install Rust from https://rustup.rs.',
  );
}
