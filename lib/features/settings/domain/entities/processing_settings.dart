import 'package:freezed_annotation/freezed_annotation.dart';

part 'processing_settings.freezed.dart';

/// How strongly noise is suppressed. [maxAttenuationDb] is the most the
/// engine may reduce noise by.
enum SuppressionStrength {
  low(12),
  medium(24),
  high(100);

  const SuppressionStrength(this.maxAttenuationDb);

  final int maxAttenuationDb;
}

/// The user's persisted processing choices.
@freezed
abstract class ProcessingSettings with _$ProcessingSettings {
  const factory ProcessingSettings({
    /// The chosen input device id; `null` means the OS default input.
    String? inputDeviceId,
    @Default(false) bool userBypass,
    @Default(true) bool agcEnabled,
    @Default(SuppressionStrength.medium) SuppressionStrength strength,
  }) = _ProcessingSettings;
}
