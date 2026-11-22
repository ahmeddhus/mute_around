import 'package:injectable/injectable.dart';
import 'package:mute_around/core/audio/audio_device.dart';
import 'package:mute_around/core/audio/audio_device_directory.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/data/datasources/engine_data_source.dart';

/// [AudioDeviceDirectory] backed by the native engine's device enumeration.
@LazySingleton(as: AudioDeviceDirectory)
class EngineAudioDeviceDirectory implements AudioDeviceDirectory {
  const EngineAudioDeviceDirectory(this._engine);

  final EngineDataSource _engine;

  @override
  Result<List<AudioDevice>> playbackDevices() => _engine.listDevices(.playback);
}
