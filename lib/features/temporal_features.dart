import 'dart:math' as math;
import '../models/stroke.dart';

/// Computes temporal features from a list of strokes.
/// Pure Dart — no Flutter dependencies.
///
/// Returns a [Map<String, double>] with keys:
///   total_duration, pen_down_duration, pen_down_ratio, pause_count,
///   mean_pause_duration, writing_tempo, rhythm_regularity
Map<String, double> computeTemporalFeatures(List<Stroke> strokes) {
  if (strokes.isEmpty) return _zeros();

  // Sort strokes by penDownTime for correct gap computation
  final sorted = List<Stroke>.from(strokes)
    ..sort((a, b) => a.penDownTime.compareTo(b.penDownTime));

  // ── Total duration (first pen-down → last pen-up) ─────────────────────────
  final firstDown = sorted.first.penDownTime;
  final lastUp = sorted.last.penUpTime;
  final totalDurationMs = (lastUp - firstDown).toDouble();

  // ── Pen-down duration (sum of all stroke durations) ───────────────────────
  double penDownMs = 0;
  final strokeDurations = <double>[];
  for (final s in sorted) {
    final dur = (s.penUpTime - s.penDownTime).toDouble().abs();
    penDownMs += dur;
    strokeDurations.add(dur);
  }

  // ── Pauses (inter-stroke gaps) ─────────────────────────────────────────────
  const pauseThresholdMs = 500.0;
  final gaps = <double>[];
  for (int i = 1; i < sorted.length; i++) {
    final gap = (sorted[i].penDownTime - sorted[i - 1].penUpTime).toDouble();
    if (gap > 0) gaps.add(gap);
  }

  final pauseGaps = gaps.where((g) => g >= pauseThresholdMs).toList();
  final pauseCount = pauseGaps.length.toDouble();
  final meanPauseDuration =
      pauseGaps.isEmpty ? 0.0 : pauseGaps.reduce((a, b) => a + b) / pauseGaps.length;

  // ── Pen-down ratio ─────────────────────────────────────────────────────────
  final penDownRatio =
      totalDurationMs > 0 ? penDownMs / totalDurationMs : 1.0;

  // ── Writing tempo (strokes per second) ────────────────────────────────────
  final totalDurationSec = totalDurationMs / 1000.0;
  final writingTempo =
      totalDurationSec > 0 ? sorted.length / totalDurationSec : 0.0;

  // ── Rhythm regularity: 1 − (σ_duration / μ_duration) ─────────────────────
  double rhythmRegularity = 1.0;
  if (strokeDurations.length >= 2) {
    final mean =
        strokeDurations.reduce((a, b) => a + b) / strokeDurations.length;
    if (mean > 0) {
      final variance = strokeDurations
              .map((d) => (d - mean) * (d - mean))
              .reduce((a, b) => a + b) /
          strokeDurations.length;
      final sigma = math.sqrt(variance);
      rhythmRegularity = _clamp01(1.0 - sigma / mean);
    }
  }

  return {
    'total_duration': _safe(totalDurationMs),
    'pen_down_duration': _safe(penDownMs),
    'pen_down_ratio': _safe(penDownRatio),
    'pause_count': _safe(pauseCount),
    'mean_pause_duration': _safe(meanPauseDuration),
    'writing_tempo': _safe(writingTempo),
    'rhythm_regularity': _safe(rhythmRegularity),
  };
}

double _safe(double v) => (v.isNaN || v.isInfinite) ? 0.0 : v;
double _clamp01(double v) => v.clamp(0.0, 1.0);

Map<String, double> _zeros() => {
      'total_duration': 0,
      'pen_down_duration': 0,
      'pen_down_ratio': 0,
      'pause_count': 0,
      'mean_pause_duration': 0,
      'writing_tempo': 0,
      'rhythm_regularity': 1,
    };
