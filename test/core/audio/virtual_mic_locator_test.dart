import 'package:flutter_test/flutter_test.dart';
import 'package:mute_around/core/audio/audio_device.dart';
import 'package:mute_around/core/audio/virtual_mic_locator.dart';

void main() {
  const speakers = AudioDevice(
    id: 'BuiltInSpeakerDevice',
    name: 'MacBook Speakers',
    isDefault: true,
  );
  const muteAround = AudioDevice(id: virtualMicUid, name: 'Mute Around');
  const cableInput = AudioDevice(
    id: '{0.0.0.00000000}.{abc}',
    name: 'CABLE Input (VB-Audio Virtual Cable)',
  );

  group('findVirtualMicSink', () {
    test('macOS matches by UID, not name', () {
      expect(
        findVirtualMicSink([speakers, muteAround], .macos),
        muteAround,
      );
      const impostor = AudioDevice(id: 'other', name: 'Mute Around');
      expect(findVirtualMicSink([speakers, impostor], .macos), isNull);
    });

    test('Windows matches the CABLE Input name prefix', () {
      expect(
        findVirtualMicSink([speakers, cableInput], .windows),
        cableInput,
      );
      expect(findVirtualMicSink([speakers], .windows), isNull);
    });

    test('returns null for an empty list', () {
      expect(findVirtualMicSink([], .macos), isNull);
      expect(findVirtualMicSink([], .windows), isNull);
    });
  });

  group('isOwnVirtualMicInput', () {
    test('macOS matches the UID only', () {
      expect(isOwnVirtualMicInput(virtualMicUid, 'x', .macos), isTrue);
      expect(isOwnVirtualMicInput('mic', 'Mute Around', .macos), isFalse);
    });

    test('Windows matches the CABLE Output name prefix', () {
      expect(
        isOwnVirtualMicInput(
          'id',
          'CABLE Output (VB-Audio Virtual Cable)',
          .windows,
        ),
        isTrue,
      );
      expect(isOwnVirtualMicInput('id', 'Microphone (USB)', .windows), isFalse);
    });
  });
}
