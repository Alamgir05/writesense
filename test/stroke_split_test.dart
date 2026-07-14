import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:writesense/models/stroke.dart';
import 'package:writesense/models/stroke_point.dart';
import 'package:writesense/features/dynamic_features.dart';

void main() {
  test('Compare single continuous stroke vs split strokes', () {
    // Generate a smooth sine wave path: x goes from 0 to 400, y is 100 + 20 * sin(x/50)
    // 101 points total, 20ms intervals (total duration 2000ms)
    final points = <StrokePoint>[];
    for (int i = 0; i <= 100; i++) {
      final double t = i * 20.0;
      final double x = i * 4.0;
      final double y = 100.0 + 20.0 * math.sin(x / 50.0);
      points.add(StrokePoint(x: x, y: y, timestamp: t.round(), pressure: 0.5));
    }

    // 1. Single Continuous Stroke
    final continuousStroke = Stroke(
      points: points,
      penDownTime: 0,
      penUpTime: 2000,
    );
    final featContinuous = computeDynamicFeatures([continuousStroke]);

    // 2. Split into 5 separate strokes (20 points each, sequential timestamps/coords)
    final List<Stroke> splitStrokes = [];
    for (int s = 0; s < 5; s++) {
      final startIndex = s * 20;
      final endIndex = startIndex + 21; // overlap by 1 to cover the same interval
      final subPoints = points.sublist(startIndex, endIndex);
      
      // We adjust timestamps and coords so that they are physically identical,
      // just separated by a tiny "pen lift" interval that doesn't change the path points.
      splitStrokes.add(Stroke(
        points: subPoints,
        penDownTime: subPoints.first.timestamp,
        penUpTime: subPoints.last.timestamp,
      ));
    }
    final featSplit = computeDynamicFeatures(splitStrokes);

    print('\n=========================================================');
    print('COMPARING CONTINUOUS VS SPLIT STROKES FOR IDENTICAL PATH:');
    print('---------------------------------------------------------');
    print('Normalized Jerk:');
    print('  Continuous: ${featContinuous['normalized_jerk']}');
    print('  Split (5):  ${featSplit['normalized_jerk']}');
    print('Velocity Variance:');
    print('  Continuous: ${featContinuous['velocity_variance']}');
    print('  Split (5):  ${featSplit['velocity_variance']}');
    print('Direction Changes:');
    print('  Continuous: ${featContinuous['direction_changes']}');
    print('  Split (5):  ${featSplit['direction_changes']}');
    print('=========================================================\n');
  });
}
