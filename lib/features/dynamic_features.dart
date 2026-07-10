import 'dart:math' as math;
import '../models/stroke.dart';
import '../models/stroke_point.dart';

/// Computes dynamic (kinematic) features from a list of strokes.
/// Pure Dart — no Flutter dependencies.
///
/// Returns a [Map<String, double>] with keys:
///   mean_velocity, max_velocity, velocity_variance,
///   mean_acceleration, mean_jerk, normalized_jerk,
///   direction_changes, tremor_frequency, tremor_amplitude
Map<String, double> computeDynamicFeatures(List<Stroke> strokes) {
  if (strokes.isEmpty) return _zeros();

  final allVelocities = <double>[];
  final allAccelerations = <double>[];
  final allJerks = <double>[];
  int totalDirectionChanges = 0;
  double totalLength = 0;
  double totalDurationMs = 0;

  for (final stroke in strokes) {
    if (stroke.points.length < 2) continue;

    final velocities = <double>[];

    // ── Velocity (speed between consecutive points) ────────────────────────
    for (int i = 1; i < stroke.points.length; i++) {
      final p0 = stroke.points[i - 1];
      final p1 = stroke.points[i];
      final dt = (p1.timestamp - p0.timestamp).toDouble(); // ms
      if (dt <= 0) continue;

      final dx = p1.x - p0.x;
      final dy = p1.y - p0.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      final speed = dist / dt; // px/ms
      velocities.add(speed);

      totalLength += dist;
      totalDurationMs += dt;
    }

    allVelocities.addAll(velocities);

    // ── Acceleration ──────────────────────────────────────────────────────
    final accelerations = <double>[];
    for (int i = 1; i < velocities.length; i++) {
      final p0 = stroke.points[i];
      final p1 = stroke.points[i + 1 < stroke.points.length ? i + 1 : i];
      final dt = (p1.timestamp - p0.timestamp).toDouble();
      if (dt <= 0) continue;
      final acc = (velocities[i] - velocities[i - 1]) / dt;
      accelerations.add(acc.abs());
    }
    allAccelerations.addAll(accelerations);

    // ── Jerk (derivative of acceleration) ────────────────────────────────
    for (int i = 1; i < accelerations.length; i++) {
      final p0 = stroke.points[i + 1 < stroke.points.length ? i + 1 : i];
      final p1 = stroke.points[i + 2 < stroke.points.length ? i + 2 : i];
      final dt = (p1.timestamp - p0.timestamp).toDouble();
      if (dt <= 0) continue;
      final jerk = (accelerations[i] - accelerations[i - 1]) / dt;
      allJerks.add(jerk.abs());
    }

    // ── Direction changes ─────────────────────────────────────────────────
    if (stroke.points.length >= 3) {
      double prevAngle = _angle(stroke.points[0], stroke.points[1]);
      for (int i = 2; i < stroke.points.length; i++) {
        final currAngle = _angle(stroke.points[i - 1], stroke.points[i]);
        final delta = (currAngle - prevAngle).abs();
        final normalised = delta > math.pi ? 2 * math.pi - delta : delta;
        if (normalised > 0.3) totalDirectionChanges++; // ~17° threshold
        prevAngle = currAngle;
      }
    }
  }

  // ── Aggregate velocity stats ───────────────────────────────────────────────
  final meanVelocity = _mean(allVelocities);
  final maxVelocity =
      allVelocities.isEmpty ? 0.0 : allVelocities.reduce(math.max);
  final velocityVariance = _variance(allVelocities);
  final meanAcceleration = _mean(allAccelerations);
  final meanJerk = _mean(allJerks);

  // ── Normalized jerk (smoothness index) ────────────────────────────────────
  // Formula: meanJerk × totalDurationMs² / totalLength
  // Higher = less smooth (more irregular)
  final normalizedJerk = (totalLength > 0 && allJerks.isNotEmpty)
      ? meanJerk * (totalDurationMs * totalDurationMs) / totalLength
      : 0.0;

  // ── Tremor: analyse high-frequency velocity oscillations ─────────────────
  // Tremor frequency approximated via zero-crossing rate of (velocity - mean)
  final tremoFreq = _zeroCrossingRate(allVelocities, meanVelocity);
  // Tremor amplitude = std-dev of velocity
  final tremorAmp = math.sqrt(velocityVariance);

  return {
    'mean_velocity': _safe(meanVelocity),
    'max_velocity': _safe(maxVelocity),
    'velocity_variance': _safe(velocityVariance),
    'mean_acceleration': _safe(meanAcceleration),
    'mean_jerk': _safe(meanJerk),
    'normalized_jerk': _safe(normalizedJerk),
    'direction_changes': _safe(totalDirectionChanges.toDouble()),
    'tremor_frequency': _safe(tremoFreq),
    'tremor_amplitude': _safe(tremorAmp),
  };
}

// ── Helpers ──────────────────────────────────────────────────────────────────

double _angle(StrokePoint p0, StrokePoint p1) =>
    math.atan2(p1.y - p0.y, p1.x - p0.x);

double _mean(List<double> vals) =>
    vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;

double _variance(List<double> vals) {
  if (vals.length < 2) return 0.0;
  final m = _mean(vals);
  return vals.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) /
      vals.length;
}

/// Zero-crossing rate of (signal - baseline) → tremor frequency proxy.
double _zeroCrossingRate(List<double> signal, double baseline) {
  if (signal.length < 2) return 0.0;
  int crossings = 0;
  bool prevAbove = signal.first > baseline;
  for (int i = 1; i < signal.length; i++) {
    final above = signal[i] > baseline;
    if (above != prevAbove) crossings++;
    prevAbove = above;
  }
  return crossings / signal.length.toDouble();
}

double _safe(double v) => (v.isNaN || v.isInfinite) ? 0.0 : v;

Map<String, double> _zeros() => {
      'mean_velocity': 0,
      'max_velocity': 0,
      'velocity_variance': 0,
      'mean_acceleration': 0,
      'mean_jerk': 0,
      'normalized_jerk': 0,
      'direction_changes': 0,
      'tremor_frequency': 0,
      'tremor_amplitude': 0,
    };
