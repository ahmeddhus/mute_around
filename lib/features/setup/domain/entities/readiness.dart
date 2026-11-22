import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/features/setup/domain/entities/mic_permission.dart';
import 'package:mute_around/features/setup/domain/entities/virtual_mic_status.dart';

part 'readiness.freezed.dart';

/// Everything processing needs before it can start: the virtual mic and
/// microphone permission.
@freezed
abstract class Readiness with _$Readiness {
  const factory Readiness({
    required HostPlatform platform,
    required VirtualMicStatus virtualMic,
    required MicPermission permission,
  }) = _Readiness;

  const Readiness._();

  /// Whether permission lets processing start. On Windows `notDetermined`
  /// passes (there is no way to ask before trying); on macOS the user must
  /// answer the prompt first.
  bool get permissionOk => switch (permission) {
    .granted => true,
    .denied => false,
    .notDetermined => platform == .windows,
  };

  bool get isReady => virtualMic is VirtualMicReady && permissionOk;
}
