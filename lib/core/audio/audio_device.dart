/// A raw audio device as reported by the engine, before any feature-specific
/// mapping. `id` is the stable OS identifier (Core Audio UID / WASAPI
/// endpoint id).
final class AudioDevice {
  const AudioDevice({
    required this.id,
    required this.name,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final bool isDefault;

  @override
  bool operator ==(Object other) =>
      other is AudioDevice &&
      other.id == id &&
      other.name == name &&
      other.isDefault == isDefault;

  @override
  int get hashCode => Object.hash(id, name, isDefault);

  @override
  String toString() => 'AudioDevice($id, $name, default: $isDefault)';
}
