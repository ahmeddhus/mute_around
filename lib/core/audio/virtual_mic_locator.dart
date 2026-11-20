import 'package:mute_around/core/audio/audio_device.dart';
import 'package:mute_around/core/platform.dart';

/// Core Audio UID of the Mute Around HAL plug-in device (macOS).
const virtualMicUid = 'com.mutearound.virtualmic';

/// Name prefix of VB-CABLE's render endpoint, which the app plays into.
const vbCableInputPrefix = 'CABLE Input';

/// Name prefix of VB-CABLE's capture endpoint, which meeting apps record from.
const vbCableOutputPrefix = 'CABLE Output';

/// Finds the virtual-mic sink among [playbackDevices]: on macOS the device
/// with UID [virtualMicUid], on Windows the first device whose name starts
/// with [vbCableInputPrefix]. Returns `null` when it isn't installed.
AudioDevice? findVirtualMicSink(
  List<AudioDevice> playbackDevices,
  HostPlatform platform,
) {
  for (final device in playbackDevices) {
    final match = switch (platform) {
      .macos => device.id == virtualMicUid,
      .windows => device.name.startsWith(vbCableInputPrefix),
    };
    if (match) return device;
  }
  return null;
}

/// Whether a capture device is the input side of our own virtual mic, which
/// must never be offered as the app's input (it would feed back into itself).
bool isOwnVirtualMicInput(String id, String name, HostPlatform platform) =>
    switch (platform) {
      .macos => id == virtualMicUid,
      .windows => name.startsWith(vbCableOutputPrefix),
    };
