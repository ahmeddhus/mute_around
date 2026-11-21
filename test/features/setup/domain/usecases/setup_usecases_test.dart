import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/setup/domain/entities/mic_permission.dart';
import 'package:mute_around/features/setup/domain/entities/readiness.dart';
import 'package:mute_around/features/setup/domain/entities/virtual_mic_status.dart';
import 'package:mute_around/features/setup/domain/repositories/setup_repository.dart';
import 'package:mute_around/features/setup/domain/usecases/check_readiness.dart';
import 'package:mute_around/features/setup/domain/usecases/install_virtual_mic.dart';
import 'package:mute_around/features/setup/domain/usecases/open_mic_privacy_settings.dart';
import 'package:mute_around/features/setup/domain/usecases/open_virtual_mic_download.dart';
import 'package:mute_around/features/setup/domain/usecases/report_mic_permission_denied.dart';
import 'package:mute_around/features/setup/domain/usecases/request_mic_permission.dart';

class MockSetupRepository extends Mock implements SetupRepository {}

void main() {
  late MockSetupRepository repository;

  setUp(() {
    repository = MockSetupRepository();
    when(
      () => repository.virtualMicStatus(),
    ).thenAnswer((_) async => const VirtualMicStatus.ready('sink'));
    when(
      () => repository.micPermission(),
    ).thenAnswer((_) async => MicPermission.granted);
  });

  group('CheckReadiness', () {
    test('combines virtual mic and permission', () async {
      final readiness = await CheckReadiness(
        repository,
        const HostInfo(.macos),
      )();
      expect(
        readiness,
        const Readiness(
          platform: .macos,
          virtualMic: VirtualMicStatus.ready('sink'),
          permission: .granted,
        ),
      );
      expect(readiness.isReady, isTrue);
      verifyNever(() => repository.clearReportedDenial());
    });

    test('retryDenied clears a reported denial before checking', () async {
      await CheckReadiness(
        repository,
        const HostInfo(.windows),
      )(retryDenied: true);
      verifyInOrder([
        () => repository.clearReportedDenial(),
        () => repository.micPermission(),
      ]);
    });
  });

  group('Readiness.isReady', () {
    Readiness r(
      HostPlatform platform,
      VirtualMicStatus mic,
      MicPermission permission,
    ) => Readiness(platform: platform, virtualMic: mic, permission: permission);
    const ready = VirtualMicStatus.ready('sink');

    test('needs the virtual mic', () {
      expect(
        r(
          .macos,
          const VirtualMicStatus.notInstalled(.macos),
          .granted,
        ).isReady,
        isFalse,
      );
      expect(
        r(
          .windows,
          const VirtualMicStatus.unknown(DeviceFailure()),
          .granted,
        ).isReady,
        isFalse,
      );
    });

    test('denied blocks on both platforms', () {
      expect(r(.macos, ready, .denied).isReady, isFalse);
      expect(r(.windows, ready, .denied).isReady, isFalse);
    });

    test('notDetermined passes on Windows only', () {
      expect(r(.windows, ready, .notDetermined).isReady, isTrue);
      expect(r(.macos, ready, .notDetermined).isReady, isFalse);
    });
  });

  test('InstallVirtualMic returns the repository result', () async {
    when(
      () => repository.installVirtualMic(),
    ).thenAnswer((_) async => const Err(UserCancelled()));
    expect(
      await InstallVirtualMic(repository)(),
      const Err<Unit>(UserCancelled()),
    );
  });

  test('RequestMicPermission returns the new permission', () async {
    when(
      () => repository.requestMicPermission(),
    ).thenAnswer((_) async => const Ok(MicPermission.granted));
    expect(
      await RequestMicPermission(repository)(),
      const Ok(MicPermission.granted),
    );
  });

  test('the link use cases and the denial report delegate', () async {
    when(
      () => repository.openMicPrivacySettings(),
    ).thenAnswer((_) async => const Ok(unit));
    when(
      () => repository.openVirtualMicDownload(),
    ).thenAnswer((_) async => const Err(UnknownFailure()));
    expect(await OpenMicPrivacySettings(repository)(), const Ok(unit));
    expect(
      await OpenVirtualMicDownload(repository)(),
      const Err<Unit>(UnknownFailure()),
    );
    ReportMicPermissionDenied(repository)();
    verify(() => repository.reportMicPermissionDenied()).called(1);
  });
}
