import 'package:injectable/injectable.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';
import 'package:mute_around/features/settings/domain/usecases/load_settings.dart';

/// Starts processing with the user's saved settings.
///
/// - Uses the saved microphone if it's connected, otherwise
///   [fallbackInputDevice].
/// - Applies the saved strength, auto gain and bypass *before* starting, so
///   the very first frame uses them.
/// - Returns the id of the microphone it started with, `Err(DeviceNotFound)`
///   when no microphone is connected at all, and `Err(VirtualMicMissing)`
///   when the virtual mic isn't installed.
@injectable
class StartPipeline {
  const StartPipeline(this._engine, this._loadSettings);

  final AudioEngineRepository _engine;
  final LoadSettings _loadSettings;

  Future<Result<String>> call() async {
    // Unreadable settings fall back to the defaults rather than blocking audio.
    final settings =
        (await _loadSettings()).valueOrNull ?? const ProcessingSettings();

    final List<InputDevice> devices;
    switch (await _engine.listInputDevices()) {
      case Ok(:final value):
        devices = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (devices.isEmpty) {
      return const Err(DeviceNotFound('No microphone is connected'));
    }
    final saved = settings.inputDeviceId;
    final inputId = saved != null && devices.any((d) => d.id == saved)
        ? saved
        : fallbackInputDevice(devices).id;

    for (final apply in [
      () => _engine.setStrength(settings.strength),
      () => _engine.setAgc(enabled: settings.agcEnabled),
      () => _engine.setBypass(enabled: settings.userBypass),
    ]) {
      if (apply() case Err(:final failure)) return Err(failure);
    }
    return switch (await _engine.start(inputDeviceId: inputId)) {
      Ok() => Ok(inputId),
      Err(:final failure) => Err(failure),
    };
  }
}

/// The device to use when the saved one isn't connected: the OS default
/// among [devices], else the first one.
///
/// [devices] is the filtered list, so this never picks our own
/// virtual mic even when the user made it the OS default input. Passing the
/// id explicitly (instead of `null`, "OS default") is what guarantees that:
/// the engine's own default would be the unfiltered one and feed the sink
/// back into itself. [devices] must not be empty.
InputDevice fallbackInputDevice(List<InputDevice> devices) =>
    devices.firstWhere((d) => d.isDefault, orElse: () => devices.first);
