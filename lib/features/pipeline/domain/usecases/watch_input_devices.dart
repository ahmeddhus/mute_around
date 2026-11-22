import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device_snapshot.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';

/// Polls the microphone list and diffs it by
/// [InputDevice.id].
///
/// Emits a snapshot on every poll, changed or not: the pipeline uses the
/// tick to retry a microphone that is still listed but stopped (a Bluetooth
/// headset switching to call mode). Lists that fail to load are skipped.
@injectable
class WatchInputDevices {
  const WatchInputDevices(this._engine);

  final AudioEngineRepository _engine;

  /// [selectedId] is read on every poll; a selected device that is gone
  /// stays in the list, marked `isConnected: false`.
  Stream<InputDeviceSnapshot> call({
    required String? Function() selectedId,
    Duration interval = const Duration(seconds: 2),
  }) {
    Timer? timer;
    Set<String>? previous;
    // Last known name of every device seen, so a missing one keeps it.
    final names = <String, String>{};
    late final StreamController<InputDeviceSnapshot> controller;

    Future<void> poll() async {
      final devices = (await _engine.listInputDevices()).valueOrNull;
      if (devices == null || controller.isClosed) return;
      final ids = {for (final d in devices) d.id};
      for (final d in devices) {
        names[d.id] = d.name;
      }
      final before = previous ?? ids;
      previous = ids;
      final selected = selectedId();
      controller.add(
        InputDeviceSnapshot(
          devices: [
            ...devices,
            if (selected != null && !ids.contains(selected))
              InputDevice(
                id: selected,
                name: names[selected] ?? InputDevice.fallbackName(selected),
                isConnected: false,
              ),
          ],
          added: ids.difference(before),
          removed: before.difference(ids),
        ),
      );
    }

    controller = StreamController<InputDeviceSnapshot>(
      onListen: () {
        unawaited(poll());
        timer = Timer.periodic(interval, (_) => unawaited(poll()));
      },
      onCancel: () {
        timer?.cancel();
        return controller.close();
      },
    );
    return controller.stream;
  }
}
