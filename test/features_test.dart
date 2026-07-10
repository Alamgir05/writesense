import 'package:flutter_test/flutter_test.dart';
import 'package:writesense/features/spatial_features.dart';
import 'package:writesense/features/temporal_features.dart';
import 'package:writesense/features/dynamic_features.dart';
import 'package:writesense/features/fluency_score.dart';
import 'package:writesense/models/stroke.dart';
import 'package:writesense/models/stroke_point.dart';

// Helper: create a simple horizontal stroke
Stroke _makeStroke(List<(double, double)> coords, {int startMs = 0}) {
  final points = coords.asMap().entries.map((e) => StrokePoint(
        x: e.value.$1,
        y: e.value.$2,
        timestamp: startMs + e.key * 50, // 50ms per point
        pressure: 0.5,
      )).toList();
  return Stroke(
    points: points,
    penDownTime: startMs,
    penUpTime: startMs + coords.length * 50,
  );
}

void main() {
  group('Spatial Features', () {
    test('returns zeros for empty strokes', () {
      final result = computeSpatialFeatures([]);
    for (final entry in result.entries) {
      expect(entry.value, equals(0.0),
          reason: '${entry.key} should be 0 for empty input');
    }
    });

    test('computes bounding box for horizontal line', () {
      final stroke = _makeStroke(
          List.generate(10, (i) => (i * 10.0, 50.0)));
      final result = computeSpatialFeatures([stroke]);
      expect(result['bounding_width'], closeTo(90.0, 1.0));
      expect(result['bounding_height'], closeTo(0.0, 1.0));
    });

    test('stroke_length is positive for multi-point stroke', () {
      final stroke = _makeStroke([(0, 0), (30, 40)]);
      final result = computeSpatialFeatures([stroke]);
      expect(result['stroke_length'], closeTo(50.0, 1.0)); // 3-4-5 triangle
    });

    test('straightness is 1.0 for perfectly straight stroke', () {
      final stroke = _makeStroke(
          List.generate(5, (i) => (i * 20.0, 0.0)));
      final result = computeSpatialFeatures([stroke]);
      expect(result['straightness'], closeTo(1.0, 0.01));
    });

    test('no NaN values in output', () {
      final stroke = _makeStroke([(0, 0), (50, 50), (100, 0)]);
      final result = computeSpatialFeatures([stroke]);
      for (final entry in result.entries) {
        expect(result[entry.key]!.isNaN, false,
            reason: '${entry.key} should not be NaN');
        expect(result[entry.key]!.isInfinite, false,
            reason: '${entry.key} should not be infinite');
      }
    });
  });

  group('Temporal Features', () {
    test('returns zeros for empty strokes', () {
      final result = computeTemporalFeatures([]);
      expect(result['total_duration'], equals(0.0));
    });

    test('pen_down_ratio between 0 and 1', () {
      final s1 = _makeStroke([(0, 0), (10, 10)], startMs: 0);
      final s2 = _makeStroke([(20, 0), (30, 10)], startMs: 1000);
      final result = computeTemporalFeatures([s1, s2]);
      final ratio = result['pen_down_ratio']!;
      expect(ratio, greaterThanOrEqualTo(0.0));
      expect(ratio, lessThanOrEqualTo(1.0));
    });

    test('rhythm_regularity is 1.0 for equal duration strokes', () {
      final strokes = List.generate(3, (i) {
        return _makeStroke(
          List.generate(5, (j) => (j * 10.0, 0.0)),
          startMs: i * 500,
        );
      });
      final result = computeTemporalFeatures(strokes);
      // All durations equal → regularity should be high
      expect(result['rhythm_regularity']!, greaterThan(0.8));
    });

    test('no NaN or infinite values', () {
      final stroke = _makeStroke([(0, 0), (10, 10)]);
      final result = computeTemporalFeatures([stroke]);
      for (final entry in result.entries) {
        expect(entry.value.isNaN, false, reason: '${entry.key} is NaN');
        expect(entry.value.isInfinite, false, reason: '${entry.key} is Inf');
      }
    });
  });

  group('Dynamic Features', () {
    test('returns zeros for empty strokes', () {
      final result = computeDynamicFeatures([]);
      expect(result['mean_velocity'], equals(0.0));
    });

    test('mean_velocity is positive for moving stroke', () {
      final stroke = _makeStroke(
          List.generate(10, (i) => (i * 5.0, 0.0)));
      final result = computeDynamicFeatures([stroke]);
      expect(result['mean_velocity']!, greaterThan(0.0));
    });

    test('no NaN values for single-point stroke', () {
      final stroke = Stroke(
        points: [const StrokePoint(x: 100, y: 100, timestamp: 1000)],
        penDownTime: 1000,
        penUpTime: 1001,
      );
      final result = computeDynamicFeatures([stroke]);
      for (final entry in result.entries) {
        expect(entry.value.isNaN, false, reason: '${entry.key} is NaN');
        expect(entry.value.isInfinite, false, reason: '${entry.key} is Inf');
      }
    });
  });

  group('Fluency Score', () {
    test('irregularity_index in [0, 1]', () {
      final spatial = computeSpatialFeatures(
          [_makeStroke([(0, 0), (100, 50), (200, 0)])]);
      final temporal = computeTemporalFeatures(
          [_makeStroke([(0, 0), (100, 50)])]);
      final dynamic_ = computeDynamicFeatures(
          [_makeStroke([(0, 0), (100, 50), (200, 0)])]);

      final result = computeFluencyScores(
          spatial: spatial, temporal: temporal, dynamic_: dynamic_);

      final idx = result['irregularity_index']!;
      expect(idx, greaterThanOrEqualTo(0.0));
      expect(idx, lessThanOrEqualTo(1.0));
    });

    test('classify returns correct labels', () {
      expect(classify(0.1), equals('Regular'));
      expect(classify(0.45), equals('Mildly Irregular'));
      expect(classify(0.75), equals('Irregular'));
    });
  });
}
