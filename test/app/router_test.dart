import 'package:flutter_test/flutter_test.dart';
import 'package:mute_around/app/router.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/features/setup/domain/entities/mic_permission.dart';
import 'package:mute_around/features/setup/domain/entities/readiness.dart';
import 'package:mute_around/features/setup/domain/entities/virtual_mic_status.dart';
import 'package:mute_around/features/setup/presentation/bloc/setup_cubit.dart';

SetupState _state(
  HostPlatform platform, {
  bool micInstalled = true,
  MicPermission permission = .granted,
}) => SetupState(
  readiness: Readiness(
    platform: platform,
    virtualMic: micInstalled
        ? const VirtualMicStatus.ready('sink')
        : VirtualMicStatus.notInstalled(platform),
    permission: permission,
  ),
);

void main() {
  test('no redirect before the first check', () {
    expect(setupRedirect(const SetupState(), '/'), isNull);
    expect(setupRedirect(const SetupState(), '/setup'), isNull);
  });

  test('Home → Setup while the virtual mic is missing', () {
    expect(setupRedirect(_state(.macos, micInstalled: false), '/'), '/setup');
    expect(setupRedirect(_state(.windows, micInstalled: false), '/'), '/setup');
  });

  test('Home → Setup when permission is denied, on both platforms', () {
    expect(setupRedirect(_state(.macos, permission: .denied), '/'), '/setup');
    expect(setupRedirect(_state(.windows, permission: .denied), '/'), '/setup');
  });

  test('notDetermined: macOS → Setup, Windows stays Home', () {
    expect(
      setupRedirect(_state(.macos, permission: .notDetermined), '/'),
      '/setup',
    );
    expect(
      setupRedirect(_state(.windows, permission: .notDetermined), '/'),
      isNull,
    );
  });

  test('Setup → Home once ready; Home stays', () {
    expect(setupRedirect(_state(.macos), '/setup'), '/');
    expect(setupRedirect(_state(.macos), '/'), isNull);
  });

  test('About is never redirected', () {
    expect(
      setupRedirect(_state(.macos, micInstalled: false), '/about'),
      isNull,
    );
  });
}
