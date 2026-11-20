import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';

/// Stores [ProcessingSettings] on this computer.
abstract interface class SettingsRepository {
  /// Loads the stored settings; missing or unknown values fall back to the
  /// defaults.
  Future<Result<ProcessingSettings>> load();

  /// Saves [settings]. Writes are debounced; the returned future completes
  /// when the write that includes these settings has finished.
  Future<Result<Unit>> save(ProcessingSettings settings);

  /// Writes any debounced changes now (e.g. before the app exits).
  Future<void> flush();
}
