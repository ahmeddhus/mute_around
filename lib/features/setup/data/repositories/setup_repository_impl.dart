import 'package:injectable/injectable.dart';
import 'package:mute_around/core/audio/audio_device_directory.dart';
import 'package:mute_around/core/audio/virtual_mic_locator.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/setup/data/datasources/external_links_data_source.dart';
import 'package:mute_around/features/setup/data/datasources/permission_data_source.dart';
import 'package:mute_around/features/setup/data/datasources/virtual_mic_installer_data_source.dart';
import 'package:mute_around/features/setup/domain/entities/mic_permission.dart';
import 'package:mute_around/features/setup/domain/entities/virtual_mic_status.dart';
import 'package:mute_around/features/setup/domain/repositories/setup_repository.dart';

@LazySingleton(as: SetupRepository)
class SetupRepositoryImpl implements SetupRepository {
  SetupRepositoryImpl(
    this._devices,
    this._permission,
    this._installer,
    this._links,
    this._host,
  );

  /// macOS: Privacy & Security → Microphone.
  static final macosPrivacySettings = Uri.parse(
    'x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone',
  );

  /// Windows: Settings → Privacy → Microphone.
  static final windowsPrivacySettings = Uri.parse(
    'ms-settings:privacy-microphone',
  );

  /// VB-Audio's official page for VB-CABLE (opened in the user's browser).
  static final vbCableDownload = Uri.parse('https://vb-audio.com/Cable/');

  final AudioDeviceDirectory _devices;
  final PermissionDataSource _permission;
  final VirtualMicInstallerDataSource _installer;
  final ExternalLinksDataSource _links;
  final HostInfo _host;

  @override
  Future<VirtualMicStatus> virtualMicStatus() async =>
      switch (_devices.playbackDevices()) {
        Ok(:final value) => switch (findVirtualMicSink(value, _host.platform)) {
          final sink? => VirtualMicStatus.ready(sink.id),
          null => VirtualMicStatus.notInstalled(_host.platform),
        },
        Err(:final failure) => VirtualMicStatus.unknown(failure),
      };

  @override
  Future<MicPermission> micPermission() => _permission.status();

  @override
  Future<Result<MicPermission>> requestMicPermission() async {
    try {
      return Ok(await _permission.request());
    } on Object catch (e) {
      // ObjC interop errors (e.g. AVFoundation failed to load).
      return Err(UnknownFailure('Could not ask for microphone access: $e'));
    }
  }

  @override
  Future<Result<Unit>> installVirtualMic() => switch (_host.platform) {
    .macos => _installer.install(),
    // VB-CABLE is installed by the user.
    .windows => Future.value(
      const Err(InstallFailure('VB-CABLE must be installed by hand')),
    ),
  };

  @override
  Future<Result<Unit>> openMicPrivacySettings() =>
      _open(switch (_host.platform) {
        .macos => macosPrivacySettings,
        .windows => windowsPrivacySettings,
      }, 'the privacy settings');

  @override
  Future<Result<Unit>> openVirtualMicDownload() =>
      _open(vbCableDownload, 'the VB-CABLE page');

  @override
  void reportMicPermissionDenied() => _permission.markDenied();

  @override
  void clearReportedDenial() => _permission.clearDenied();

  Future<Result<Unit>> _open(Uri uri, String what) async =>
      await _links.open(uri)
      ? const Ok(unit)
      : Err(UnknownFailure('Could not open $what ($uri)'));
}
