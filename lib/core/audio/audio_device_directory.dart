import 'package:mute_around/core/audio/audio_device.dart';
import 'package:mute_around/core/result.dart';

/// Lists the computer's playback devices. Lets features other than
/// `pipeline` find the virtual-mic sink without importing the engine's data
/// layer; the pipeline feature provides the implementation.
abstract interface class AudioDeviceDirectory {
  Result<List<AudioDevice>> playbackDevices();
}
