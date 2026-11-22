import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/setup/data/datasources/virtual_mic_installer_data_source.dart';

void main() {
  const app = "/Applications/Mute Around's.app";
  const driver = '$app/Contents/Resources/MuteAround.driver';
  final calls = <List<String>>[];

  MacosHalInstallerDataSource installer({
    int exitCode = 0,
    String stderr = '',
    bool exists = true,
  }) => MacosHalInstallerDataSource(
    bundledDriverPath: driver,
    driverExists: (_) => exists,
    runProcess: (exe, args) async {
      calls.add([exe, ...args]);
      return ProcessResult(1, exitCode, '', stderr);
    },
  );

  setUp(calls.clear);

  test('runs osascript with administrator privileges', () async {
    expect(await installer().install(), const Ok(unit));
    expect(calls.single.first, '/usr/bin/osascript');
    final script = calls.single.last;
    expect(script, startsWith('do shell script "'));
    expect(script, endsWith('" with administrator privileges'));
    expect(script, contains('/Library/Audio/Plug-Ins/HAL/MuteAround.driver'));
    expect(script, contains('killall -9 coreaudiod'));
  });

  test('quotes the bundle path for the shell', () {
    final script = MacosHalInstallerDataSource.installScript(driver);
    // The apostrophe is closed, escaped and reopened inside single quotes.
    expect(script, contains(r"'/Applications/Mute Around'\\''s.app/"));
  });

  test('user cancel (-128) → UserCancelled', () async {
    expect(
      (await installer(
        exitCode: 1,
        stderr: 'execution error: User canceled. (-128)',
      ).install()).failureOrNull,
      isA<UserCancelled>(),
    );
  });

  test('other errors → InstallFailure with the detail', () async {
    expect(
      await installer(exitCode: 1, stderr: 'cp: denied').install(),
      const Err<Unit>(InstallFailure('cp: denied')),
    );
  });

  test('missing bundle → InstallFailure, nothing run', () async {
    expect(
      (await installer(exists: false).install()).failureOrNull,
      isA<InstallFailure>(),
    );
    expect(calls, isEmpty);
  });
}
