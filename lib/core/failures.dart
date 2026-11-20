/// Why an operation failed. Repositories map native and OS errors to these
/// at the `data/` boundary; the UI turns them into plain-language messages.
sealed class Failure {
  const Failure([this.detail = '']);

  /// Technical detail for diagnostics (English, not shown as the main message).
  final String detail;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is Failure &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(runtimeType, detail);

  @override
  String toString() =>
      detail.isEmpty ? '$runtimeType' : '$runtimeType($detail)';
}

/// The OS refused microphone access.
final class PermissionDenied extends Failure {
  const PermissionDenied([super.detail]);
}

/// The requested audio device isn't connected.
final class DeviceNotFound extends Failure {
  const DeviceNotFound([super.detail]);
}

/// An audio device failed to open or start.
final class DeviceFailure extends Failure {
  const DeviceFailure([super.detail]);
}

/// The noise-suppression model failed to load.
final class ModelLoadFailure extends Failure {
  const ModelLoadFailure([super.detail]);
}

/// The engine was called in the wrong state, or its ABI doesn't match.
final class EngineStateFailure extends Failure {
  const EngineStateFailure([super.detail]);
}

/// The virtual microphone sink (Mute Around / VB-CABLE) isn't installed.
final class VirtualMicMissing extends Failure {
  const VirtualMicMissing([super.detail]);
}

/// Anything else.
final class UnknownFailure extends Failure {
  const UnknownFailure([super.detail]);
}
