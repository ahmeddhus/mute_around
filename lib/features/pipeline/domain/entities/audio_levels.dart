import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_levels.freezed.dart';

/// Live loudness of the raw input and the processed output, in dBFS
/// (−90…0). Runtime only, never stored.
@freezed
abstract class AudioLevels with _$AudioLevels {
  const factory AudioLevels({
    @Default(AudioLevels.floorDb) double inputPeakDb,
    @Default(AudioLevels.floorDb) double inputRmsDb,
    @Default(AudioLevels.floorDb) double outputPeakDb,
    @Default(AudioLevels.floorDb) double outputRmsDb,
  }) = _AudioLevels;

  /// The quietest level reported; silence.
  static const floorDb = -90.0;

  /// Silence on both meters.
  static const silent = AudioLevels();
}
