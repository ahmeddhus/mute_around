import 'package:material_ui/material_ui.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device.dart';

/// Picks the microphone to clean up. Changing it switches
/// live; the virtual mic keeps running.
class InputDeviceDropdown extends StatelessWidget {
  const InputDeviceDropdown({
    super.key,
    required this.devices,
    required this.selectedId,
    required this.onSelected,
  });

  final List<InputDevice> devices;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final connected = devices.where((d) => d.isConnected).toList();
    final selected = devices.where((d) => d.id == selectedId).firstOrNull;
    final disconnected = selected != null && !selected.isConnected;
    final String? helper;
    if (connected.isEmpty) {
      helper = 'No microphone — connect one to start.';
    } else if (disconnected) {
      helper =
          'Microphone disconnected. Plug it back in or pick another one; '
          'meeting apps hear silence meanwhile.';
    } else {
      helper = null;
    }
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Microphone',
        helperText: helper,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
        enabled: connected.isNotEmpty,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          isDense: true,
          value: selected?.id,
          hint: Text(connected.isEmpty ? 'No microphone' : 'Choose…'),
          onChanged: connected.isEmpty
              ? null
              : (id) {
                  if (id != null && id != selectedId) onSelected(id);
                },
          items: [
            for (final d in devices)
              DropdownMenuItem(
                value: d.id,
                enabled: d.isConnected,
                child: Text(
                  d.isConnected ? d.name : '${d.name} (disconnected)',
                  overflow: .ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
