import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:mute_around/features/pipeline/domain/entities/audio_levels.dart';

/// A horizontal level meter: an RMS bar with a peak marker, in dBFS.
/// The peak falls back with a 300 ms time constant, so
/// short sounds stay visible. Screen readers get the level as text.
class LevelMeter extends StatefulWidget {
  const LevelMeter({
    super.key,
    required this.label,
    required this.peakDb,
    required this.rmsDb,
    this.clock = _now,
  });

  final String label;
  final double peakDb;
  final double rmsDb;

  /// Time source for the decay (tests inject one).
  final Duration Function() clock;

  /// The meter spans −60…0 dBFS; anything quieter shows as empty.
  static const minDb = -60.0;

  /// Peak decay time constant.
  static const decay = Duration(milliseconds: 300);

  static Duration _now() =>
      Duration(microseconds: DateTime.now().microsecondsSinceEpoch);

  @override
  State<LevelMeter> createState() => _LevelMeterState();
}

class _LevelMeterState extends State<LevelMeter> {
  late double _peakDb;
  late Duration _at;

  @override
  void initState() {
    super.initState();
    _peakDb = widget.peakDb;
    _at = widget.clock();
  }

  @override
  void didUpdateWidget(LevelMeter old) {
    super.didUpdateWidget(old);
    final now = widget.clock();
    final dt = (now - _at).inMicroseconds / 1e6;
    _at = now;
    // Exponential fall of the linear amplitude, expressed in dB.
    final fallDb =
        20 * dt / (LevelMeter.decay.inMicroseconds / 1e6) / math.ln10;
    _peakDb = math.max(widget.peakDb, _peakDb - fallDb);
  }

  static double _fraction(double db) =>
      ((db - LevelMeter.minDb) / -LevelMeter.minDb).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final peak = math.max(_peakDb, AudioLevels.floorDb);
    final value = peak <= AudioLevels.floorDb ? 'silent' : '${peak.round()} dB';
    return Semantics(
      label: widget.label,
      value: value,
      child: ExcludeSemantics(
        child: Row(
          spacing: 12,
          children: [
            SizedBox(width: 56, child: Text(widget.label)),
            Expanded(
              child: SizedBox(
                height: 12,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: .circular(6),
                          ),
                        ),
                        Container(
                          width: w * _fraction(widget.rmsDb),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: .circular(6),
                          ),
                        ),
                        Positioned(
                          left: math.max(0, w * _fraction(peak) - 2),
                          top: 0,
                          bottom: 0,
                          child: Container(width: 2, color: scheme.tertiary),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                value,
                textAlign: .end,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Input (raw) and output (processed) meters fed by [levels].
class LevelMeters extends StatelessWidget {
  const LevelMeters({super.key, required this.levels});

  final AudioLevels levels;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        LevelMeter(
          label: 'Input',
          peakDb: levels.inputPeakDb,
          rmsDb: levels.inputRmsDb,
        ),
        LevelMeter(
          label: 'Output',
          peakDb: levels.outputPeakDb,
          rmsDb: levels.outputRmsDb,
        ),
      ],
    );
  }
}
