import 'dart:math' as math;
import '../models/stroke.dart';

/// Computes spatial features from a list of strokes.
/// All functions are pure — no Flutter dependencies, fully unit-testable.
///
/// Returns a [Map<String, double>] with the following keys:
///   stroke_length, bounding_width, bounding_height, aspect_ratio,
///   mean_slant, mean_curvature, straightness, writing_density,
///   baseline_deviation, center_of_mass_x, center_of_mass_y
Map<String, double> computeSpatialFeatures(List<Stroke> strokes) {
  if (strokes.isEmpty) return _zeros();

  final allPoints = strokes.expand((s) => s.points).toList();
  if (allPoints.isEmpty) return _zeros();

  // ── Bounding box ─────────────────────────────────────────────────────────
  double minX = allPoints.first.x,
      maxX = allPoints.first.x,
      minY = allPoints.first.y,
      maxY = allPoints.first.y;

  for (final p in allPoints) {
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
  }

  final boundingWidth = maxX - minX;
  final boundingHeight = maxY - minY;
  final boundingArea = boundingWidth * boundingHeight;

  // ── Stroke length (sum of arc lengths) ────────────────────────────────────
  double totalLength = 0;
  double totalSlant = 0;
  int slantCount = 0;
  double totalCurvature = 0;
  int curvatureCount = 0;
  double totalDisplacement = 0;

  for (final stroke in strokes) {
    if (stroke.points.length < 2) continue;

    double strokeLen = 0;
    double prevAngle = 0;
    bool hasPrevAngle = false;

    for (int i = 1; i < stroke.points.length; i++) {
      final p0 = stroke.points[i - 1];
      final p1 = stroke.points[i];
      final dx = p1.x - p0.x;
      final dy = p1.y - p0.y;
      final segLen = math.sqrt(dx * dx + dy * dy);
      strokeLen += segLen;

      if (segLen > 0) {
        // Slant: angle of the tangent vector (atan2 gives radians; positive=down-right)
        final angle = math.atan2(dy, dx);
        totalSlant += angle;
        slantCount++;

        // Curvature: absolute angular change between consecutive tangents
        if (hasPrevAngle) {
          double delta = (angle - prevAngle).abs();
          // Normalize to [0, π]
          if (delta > math.pi) delta = 2 * math.pi - delta;
          totalCurvature += delta;
          curvatureCount++;
        }
        prevAngle = angle;
        hasPrevAngle = true;
      }
    }

    totalLength += strokeLen;

    // Displacement: straight-line distance from first to last point
    if (stroke.points.isNotEmpty) {
      final first = stroke.points.first;
      final last = stroke.points.last;
      final dx = last.x - first.x;
      final dy = last.y - first.y;
      totalDisplacement += math.sqrt(dx * dx + dy * dy);
    }
  }

  // ── Center of mass ─────────────────────────────────────────────────────────
  final comX = allPoints.map((p) => p.x).reduce((a, b) => a + b) / allPoints.length;
  final comY = allPoints.map((p) => p.y).reduce((a, b) => a + b) / allPoints.length;

  // ── Baseline deviation (std-dev of stroke endpoint y-coords) ─────────────
  final endpointYs = strokes
      .where((s) => s.points.isNotEmpty)
      .map((s) => s.points.last.y)
      .toList();
  final baselineDev = _stdDev(endpointYs);

  // ── Derived metrics ────────────────────────────────────────────────────────
  final aspectRatio = boundingHeight > 0 ? boundingWidth / boundingHeight : 0.0;
  final meanSlant = slantCount > 0 ? totalSlant / slantCount : 0.0;
  final meanCurvature = curvatureCount > 0 ? totalCurvature / curvatureCount : 0.0;
  final straightness =
      totalLength > 0 ? totalDisplacement / totalLength : 1.0;
  final writingDensity =
      boundingArea > 0 ? totalLength / boundingArea : 0.0;

  return {
    'stroke_length': _safe(totalLength),
    'bounding_width': _safe(boundingWidth),
    'bounding_height': _safe(boundingHeight),
    'aspect_ratio': _safe(aspectRatio),
    'mean_slant': _safe(meanSlant),
    'mean_curvature': _safe(meanCurvature),
    'straightness': _safe(straightness),
    'writing_density': _safe(writingDensity),
    'baseline_deviation': _safe(baselineDev),
    'center_of_mass_x': _safe(comX),
    'center_of_mass_y': _safe(comY),
  };
}

// ── Helpers ──────────────────────────────────────────────────────────────────

double _stdDev(List<double> values) {
  if (values.length < 2) return 0.0;
  final mean = values.reduce((a, b) => a + b) / values.length;
  final variance =
      values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
          values.length;
  return math.sqrt(variance);
}

double _safe(double v) => (v.isNaN || v.isInfinite) ? 0.0 : v;

Map<String, double> _zeros() => {
      'stroke_length': 0,
      'bounding_width': 0,
      'bounding_height': 0,
      'aspect_ratio': 0,
      'mean_slant': 0,
      'mean_curvature': 0,
      'straightness': 0,
      'writing_density': 0,
      'baseline_deviation': 0,
      'center_of_mass_x': 0,
      'center_of_mass_y': 0,
    };
