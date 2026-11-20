/// A microphone the user can choose.
///
/// Equality is by [id] only: the same device
/// keeps its identity when its name or default flag changes. That's why this
/// is a hand-written class instead of a `@freezed` one, which compares every
/// field.
final class InputDevice {
  InputDevice({
    required this.id,
    required String name,
    this.isDefault = false,
    this.isConnected = true,
  }) : name = name.isEmpty ? fallbackName(id) : name;

  /// Stable OS identifier (Core Audio UID / WASAPI endpoint id).
  final String id;

  /// Human-readable, never empty.
  final String name;

  /// Whether this is the OS default input.
  final bool isDefault;

  /// `false` for a previously selected device that is currently absent.
  final bool isConnected;

  /// Name shown for a device the OS reports without one.
  static String fallbackName(String id) =>
      'Microphone (${id.length > 6 ? id.substring(id.length - 6) : id})';

  InputDevice copyWith({String? name, bool? isDefault, bool? isConnected}) =>
      InputDevice(
        id: id,
        name: name ?? this.name,
        isDefault: isDefault ?? this.isDefault,
        isConnected: isConnected ?? this.isConnected,
      );

  @override
  bool operator ==(Object other) => other is InputDevice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'InputDevice($id, $name, default: $isDefault, connected: $isConnected)';
}
