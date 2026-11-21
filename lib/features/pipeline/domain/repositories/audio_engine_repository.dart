import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/audio_levels.dart';
import 'package:mute_around/features/pipeline/domain/entities/engine_stats.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';

/// The real-time voice engine: capture → noise suppression → virtual mic.
abstract interface class AudioEngineRepository {
  /// Microphones the user can choose, without our own virtual mic.
  Future<Result<List<InputDevice>>> listInputDevices();

  /// Starts processing from [inputDeviceId] (`null`: the OS default input)
  /// into the virtual-mic sink. Returns `Err(VirtualMicMissing)` when the
  /// sink isn't installed.
  Future<Result<Unit>> start({String? inputDeviceId});

  /// Switches the running engine to [inputDeviceId]; the virtual
  /// mic keeps running and carries silence meanwhile.
  Future<Result<Unit>> switchInput(String inputDeviceId);

  /// Stops processing; the virtual mic goes silent.
  Future<Result<Unit>> stop();

  /// These take effect at the next 10 ms frame and may be called before
  /// [start], so the first frame already uses them.
  Result<Unit> setBypass({required bool enabled});
  Result<Unit> setAgc({required bool enabled});
  Result<Unit> setStrength(SuppressionStrength strength);

  /// Engine status while running, emitted on change.
  Stream<PipelineStatus> watchStatus();

  /// Input and output levels, at most 30 per second, while the UI is
  /// visible.
  Stream<AudioLevels> watchLevels();

  /// Engine diagnostics.
  Result<EngineStats> stats();

  /// Polls faster while the window is visible (30 Hz) than while it's hidden
  /// in the tray (4 Hz).
  void setUiVisible({required bool visible});
}
