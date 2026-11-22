import 'package:freezed_annotation/freezed_annotation.dart';

part 'engine_stats.freezed.dart';

/// Engine diagnostics shown on the About page (`me_get_stats`).
@freezed
abstract class EngineStats with _$EngineStats {
  const factory EngineStats({
    /// 10 ms frames processed since start (wraps).
    required int framesProcessed,

    /// Rolling average processing time per 10 ms frame.
    required double avgProcessMs,

    /// Estimated added latency, capture → sink, without the virtual device.
    required double estimatedLatencyMs,

    /// Times the sink ran out of audio.
    required int underruns,

    /// Times processing fell behind and was bypassed automatically.
    required int overloadEvents,
  }) = _EngineStats;
}
