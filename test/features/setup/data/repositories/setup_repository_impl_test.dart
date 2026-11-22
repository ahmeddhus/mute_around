import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/audio/audio_device.dart';
import 'package:mute_around/core/audio/audio_device_directory.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/setup/data/datasources/external_links_data_source.dart';
import 'package:mute_around/features/setup/data/datasources/permission_data_source.dart';
import 'package:mute_around/features/setup/data/datasources/virtual_mic_installer_data_source.dart';
import 'package:mute_around/features/setup/data/repositories/setup_repository_impl.dart';
import 'package:mute_around/features/setup/domain/entities/mic_permission.dart';
import 'package:mute_around/features/setup/domain/entities/virtual_mic_status.dart';

class MockDirectory extends Mock implements AudioDeviceDirectory {}

class MockInstaller extends Mock implements VirtualMicInstallerDataSource {}

class MockLinks extends Mock implements ExternalLinksDataSource {}

void main() {
  late MockDirectory devices;
  late MockInstaller installer;
  late MockLinks links;

  const speakers = AudioDevice(id: 'BuiltInSpeaker', name: 'Speakers');
  const muteAround = AudioDevice(
    id: 'com.mutearound.virtualmic',
    name: 'Mute Around',
  );
  const cable = AudioDevice(
    id: '{0.0.0.00000000}.{cable}',
    name: 'CABLE Input (VB-Audio Virtual Cable)',
  );

  setUpAll(() => registerFallbackValue(Uri()));

  setUp(() {
    devices = MockDirectory();
    installer = MockInstaller();
    links = MockLinks();
    when(() => links.open(any())).thenAnswer((_) async => true);
  });

  SetupRepositoryImpl repo(
    HostPlatform platform, {
    PermissionDataSource? permission,
  }) => SetupRepositoryImpl(
    devices,
    permission ?? PlatformPermissionDataSource(HostInfo(platform)),
    installer,
    links,
    HostInfo(platform),
  );

  group('virtualMicStatus', () {
    test(
      'macOS: ready when the Mute Around UID is a playback device',
      () async {
        when(
          () => devices.playbackDevices(),
        ).thenReturn(const Ok([speakers, muteAround]));
        expect(
          await repo(.macos).virtualMicStatus(),
          const VirtualMicStatus.ready('com.mutearound.virtualmic'),
        );
      },
    );

    test('macOS: VB-CABLE does not count', () async {
      when(
        () => devices.playbackDevices(),
      ).thenReturn(const Ok([speakers, cable]));
      expect(
        await repo(.macos).virtualMicStatus(),
        const VirtualMicStatus.notInstalled(.macos),
      );
    });

    test('Windows: ready when a "CABLE Input" device exists', () async {
      when(
        () => devices.playbackDevices(),
      ).thenReturn(const Ok([speakers, cable]));
      expect(
        await repo(.windows).virtualMicStatus(),
        VirtualMicStatus.ready(cable.id),
      );
    });

    test('Windows: missing', () async {
      when(() => devices.playbackDevices()).thenReturn(const Ok([speakers]));
      expect(
        await repo(.windows).virtualMicStatus(),
        const VirtualMicStatus.notInstalled(.windows),
      );
    });

    test('listing fails → unknown', () async {
      when(
        () => devices.playbackDevices(),
      ).thenReturn(const Err(DeviceFailure('x')));
      expect(
        await repo(.windows).virtualMicStatus(),
        const VirtualMicStatus.unknown(DeviceFailure('x')),
      );
    });
  });

  group('permission', () {
    test('Windows: notDetermined until a denial is reported', () async {
      final r = repo(.windows);
      expect(await r.micPermission(), MicPermission.notDetermined);
      r.reportMicPermissionDenied();
      expect(await r.micPermission(), MicPermission.denied);
      r.clearReportedDenial();
      expect(await r.micPermission(), MicPermission.notDetermined);
    });

    test('a request that throws becomes Err', () async {
      final permission = _ThrowingPermission();
      expect(
        (await repo(
          .macos,
          permission: permission,
        ).requestMicPermission()).failureOrNull,
        isA<UnknownFailure>(),
      );
    });
  });

  group('installVirtualMic', () {
    test('macOS: runs the installer; cancel stays a Failure', () async {
      when(
        () => installer.install(),
      ).thenAnswer((_) async => const Err(UserCancelled()));
      expect(
        await repo(.macos).installVirtualMic(),
        const Err<Unit>(UserCancelled()),
      );
    });

    test('Windows: never runs an installer', () async {
      expect(
        (await repo(.windows).installVirtualMic()).failureOrNull,
        isA<InstallFailure>(),
      );
      verifyNever(() => installer.install());
    });
  });

  group('links', () {
    test('privacy settings per platform', () async {
      await repo(.macos).openMicPrivacySettings();
      verify(
        () => links.open(SetupRepositoryImpl.macosPrivacySettings),
      ).called(1);
      await repo(.windows).openMicPrivacySettings();
      verify(
        () => links.open(Uri.parse('ms-settings:privacy-microphone')),
      ).called(1);
    });

    test('VB-CABLE page; nothing opened → Err', () async {
      when(() => links.open(any())).thenAnswer((_) async => false);
      expect(
        (await repo(.windows).openVirtualMicDownload()).failureOrNull,
        isA<UnknownFailure>(),
      );
      verify(() => links.open(SetupRepositoryImpl.vbCableDownload)).called(1);
    });
  });
}

class _ThrowingPermission extends Fake implements PermissionDataSource {
  @override
  Future<MicPermission> request() => Future.error(StateError('no AVF'));
}
