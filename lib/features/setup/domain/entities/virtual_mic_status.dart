import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/platform.dart';

part 'virtual_mic_status.freezed.dart';

/// Whether the virtual microphone sink is installed.
@freezed
sealed class VirtualMicStatus with _$VirtualMicStatus {
  /// Installed; the app plays into [sinkDeviceId].
  const factory VirtualMicStatus.ready(String sinkDeviceId) = VirtualMicReady;

  /// Missing: the Mute Around plug-in (macOS) or VB-CABLE (Windows).
  const factory VirtualMicStatus.notInstalled(HostPlatform platform) =
      VirtualMicNotInstalled;

  /// The audio devices couldn't be listed.
  const factory VirtualMicStatus.unknown(Failure failure) = VirtualMicUnknown;
}
