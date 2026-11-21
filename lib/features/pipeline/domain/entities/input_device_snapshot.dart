import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device.dart';

part 'input_device_snapshot.freezed.dart';

/// One poll of the microphone list.
@freezed
abstract class InputDeviceSnapshot with _$InputDeviceSnapshot {
  const factory InputDeviceSnapshot({
    /// Connected microphones, plus the selected one marked
    /// `isConnected: false` if it's gone.
    required List<InputDevice> devices,

    /// Ids that appeared since the previous poll.
    @Default(<String>{}) Set<String> added,

    /// Ids that went away since the previous poll.
    @Default(<String>{}) Set<String> removed,
  }) = _InputDeviceSnapshot;

  const InputDeviceSnapshot._();

  /// The microphones that are actually connected.
  List<InputDevice> get connected => [
    for (final d in devices)
      if (d.isConnected) d,
  ];

  bool get hasChanges => added.isNotEmpty || removed.isNotEmpty;
}
