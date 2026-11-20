import 'package:mute_around/core/audio/audio_device.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';

/// Mirrors the native `me_status` values.
enum EngineStatus {
  stopped,
  running,
  bypassedUser,
  bypassedOverload,
  deviceDisconnected,
  error,
}

/// Mirrors the native `me_device_kind` values.
enum DeviceKind { capture, playback }

/// The native audio engine behind `mute_engine.h`. Every method returns a
/// [Result]; nothing throws across this boundary.
abstract interface class EngineDataSource {
  /// Lists devices of [kind] (raw: the own virtual mic is not filtered out).
  Result<List<AudioDevice>> listDevices(DeviceKind kind);

  /// Starts capture from [captureId] (`null`: OS default) into [sinkId].
  Result<Unit> start({String? captureId, String? sinkId});

  Result<Unit> stop();

  Result<Unit> setBypass({required bool enabled});
  Result<Unit> setAgc({required bool enabled});
  Result<Unit> setStrength(SuppressionStrength strength);

  /// Engine status, polled while someone listens and emitted on change:
  /// at 30 Hz while the UI is visible, 4 Hz while hidden.
  Stream<EngineStatus> get status;

  void setVisible({required bool visible});

  /// Stops the engine, frees it and closes [status].
  Future<void> dispose();
}
