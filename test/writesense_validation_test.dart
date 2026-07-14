import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:writesense/models/stroke.dart';
import 'package:writesense/models/stroke_point.dart';
import 'package:writesense/features/spatial_features.dart';
import 'package:writesense/features/temporal_features.dart';
import 'package:writesense/features/dynamic_features.dart';
import 'package:writesense/features/fluency_score.dart';
import 'package:writesense/services/image_processing_service.dart';

void main() {
  group('Step 2: Determinism Check', () {
    test('Image analysis is deterministic', () async {
      final file = File('handwriting_sample.png');
      expect(file.existsSync(), isTrue, reason: 'handwriting_sample.png must exist');
      
      final bytes = await file.readAsBytes();
      final service = ImageProcessingService();
      
      // Analyze run 1
      final res1 = await service.analyzeImage(bytes);
      // Analyze run 2
      final res2 = await service.analyzeImage(bytes);
      
      print('\n--- DETERMINISM CHECK ---');
      print('Run 1 Score: ${res1.staticHandwritingScore}');
      print('Run 2 Score: ${res2.staticHandwritingScore}');
      
      expect(res1.staticHandwritingScore, equals(res2.staticHandwritingScore));
      
      res1.features.forEach((key, val1) {
        final val2 = res2.features[key];
        print('Feature [$key]: Run 1 = $val1, Run 2 = $val2');
        expect(val1, equals(val2), reason: 'Feature $key should be identical');
      });
      print('-------------------------\n');
    });
  });

  group('Step 3: Known-Input Sanity Checks', () {
    test('Evaluate different stroke profiles', () {
      // a) Perfectly straight horizontal stroke
      final straightPoints = List.generate(11, (i) => StrokePoint(
        x: i * 10.0, // 0 to 100
        y: 50.0,
        timestamp: i * 50, // 0 to 500 ms
        pressure: 0.5,
      ));
      final straightStroke = Stroke(
        points: straightPoints,
        penDownTime: 0,
        penUpTime: 500,
      );

      // b) Deliberately jittery/wavy stroke
      final wavyPoints = List.generate(11, (i) {
        // y oscillates using sine wave to ensure varying segment lengths and speeds
        final yOffset = 15.0 * math.sin(i * 1.5);
        return StrokePoint(
          x: i * 10.0,
          y: 50.0 + yOffset,
          timestamp: i * 50,
          pressure: 0.5,
        );
      });
      final wavyStroke = Stroke(
        points: wavyPoints,
        penDownTime: 0,
        penUpTime: 500,
      );

      // c) Single tap (1 point)
      final tapStroke = Stroke(
        points: [const StrokePoint(x: 50.0, y: 50.0, timestamp: 0, pressure: 0.5)],
        penDownTime: 0,
        penUpTime: 1,
      );

      // c-ii) Near-zero-length stroke (2 points in same place)
      final zeroLenStroke = Stroke(
        points: [
          const StrokePoint(x: 50.0, y: 50.0, timestamp: 0, pressure: 0.5),
          const StrokePoint(x: 50.0, y: 50.0, timestamp: 1, pressure: 0.5),
        ],
        penDownTime: 0,
        penUpTime: 1,
      );

      // Analyze straight
      final spStraight = computeSpatialFeatures([straightStroke]);
      final tmStraight = computeTemporalFeatures([straightStroke]);
      final dyStraight = computeDynamicFeatures([straightStroke]);
      final scStraight = computeFluencyScores(spatial: spStraight, temporal: tmStraight, dynamic_: dyStraight);

      // Analyze wavy
      final spWavy = computeSpatialFeatures([wavyStroke]);
      final tmWavy = computeTemporalFeatures([wavyStroke]);
      final dyWavy = computeDynamicFeatures([wavyStroke]);
      final scWavy = computeFluencyScores(spatial: spWavy, temporal: tmWavy, dynamic_: dyWavy);

      // Analyze tap
      final spTap = computeSpatialFeatures([tapStroke]);
      final tmTap = computeTemporalFeatures([tapStroke]);
      final dyTap = computeDynamicFeatures([tapStroke]);
      final scTap = computeFluencyScores(spatial: spTap, temporal: tmTap, dynamic_: dyTap);

      // Analyze zero length
      final spZero = computeSpatialFeatures([zeroLenStroke]);
      final tmZero = computeTemporalFeatures([zeroLenStroke]);
      final dyZero = computeDynamicFeatures([zeroLenStroke]);
      final scZero = computeFluencyScores(spatial: spZero, temporal: tmZero, dynamic_: dyZero);

      print('\n--- STROKE SANITY CHECKS ---');
      print('a) Straight Stroke:');
      print('   Slant: ${spStraight['mean_slant']} rad (${(spStraight['mean_slant']! * 180 / math.pi).toStringAsFixed(2)}°)');
      print('   Straightness: ${spStraight['straightness']}');
      print('   Jerk (normalized_jerk): ${dyStraight['normalized_jerk']}');
      print('   Tremor Amplitude: ${dyStraight['tremor_amplitude']}');
      print('   Irregularity Index: ${scStraight['irregularity_index']}');

      print('b) Wavy Stroke:');
      print('   Slant: ${spWavy['mean_slant']} rad (${(spWavy['mean_slant']! * 180 / math.pi).toStringAsFixed(2)}°)');
      print('   Straightness: ${spWavy['straightness']}');
      print('   Jerk (normalized_jerk): ${dyWavy['normalized_jerk']}');
      print('   Tremor Amplitude: ${dyWavy['tremor_amplitude']}');
      print('   Irregularity Index: ${scWavy['irregularity_index']}');

      print('c) Single Tap Stroke:');
      print('   Straightness: ${spTap['straightness']}');
      print('   Irregularity Index: ${scTap['irregularity_index']}');

      print('c-ii) Near-Zero-Length Stroke:');
      print('   Straightness: ${spZero['straightness']}');
      print('   Irregularity Index: ${scZero['irregularity_index']}');
      
      // Confirm expected direction of metrics
      expect(spStraight['straightness'], greaterThan(spWavy['straightness']!));
      expect(dyWavy['normalized_jerk'], greaterThan(dyStraight['normalized_jerk']!));
      expect(dyWavy['tremor_amplitude'], greaterThan(dyStraight['tremor_amplitude']!));
      expect(scWavy['irregularity_index'], greaterThan(scStraight['irregularity_index']!));
      
      // Confirm zero/tap stroke is safe and does not have NaNs
      spTap.forEach((k, v) => expect(v.isNaN, isFalse));
      tmTap.forEach((k, v) => expect(v.isNaN, isFalse));
      dyTap.forEach((k, v) => expect(v.isNaN, isFalse));
      scTap.forEach((k, v) => expect(v.isNaN, isFalse));

      spZero.forEach((k, v) => expect(v.isNaN, isFalse));
      tmZero.forEach((k, v) => expect(v.isNaN, isFalse));
      dyZero.forEach((k, v) => expect(v.isNaN, isFalse));
      scZero.forEach((k, v) => expect(v.isNaN, isFalse));
      print('----------------------------\n');
    });
  });

  group('Step 4: Edge Case Robustness (Image Upload)', () {
    test('Image processor handles white and low contrast safely', () async {
      final service = ImageProcessingService();

      // a) A blank/plain white image
      final whiteImg = img.Image(width: 300, height: 300);
      img.fill(whiteImg, color: img.ColorRgb8(255, 255, 255));
      final whiteBytes = Uint8List.fromList(img.encodePng(whiteImg));

      final resWhite = await service.analyzeImage(whiteBytes);

      // b) A very low-contrast photo (solid light gray with tiny variation < local threshold threshold)
      final lowContrastImg = img.Image(width: 300, height: 300);
      img.fill(lowContrastImg, color: img.ColorRgb8(200, 200, 200));
      // Put a tiny, almost invisible line (gray level 195, diff of 5)
      for (int i = 50; i < 250; i++) {
        lowContrastImg.setPixel(i, 150, img.ColorRgb8(195, 195, 195));
      }
      final lowContrastBytes = Uint8List.fromList(img.encodePng(lowContrastImg));

      final resLowContrast = await service.analyzeImage(lowContrastBytes);

      print('\n--- IMAGE EDGE CASE ROBUSTNESS ---');
      print('a) Blank White Image:');
      print('   Total features present: ${resWhite.features.length}');
      print('   Score: ${resWhite.staticHandwritingScore}');
      resWhite.features.forEach((k, v) {
        print('     $k = $v');
      });

      print('b) Low Contrast Image:');
      print('   Total features present: ${resLowContrast.features.length}');
      print('   Score: ${resLowContrast.staticHandwritingScore}');
      resLowContrast.features.forEach((k, v) {
        print('     $k = $v');
      });
      
      // Confirm all values are returned as 0.0 (graceful fallback) and not NaN
      expect(resWhite.staticHandwritingScore, equals(0.0));
      resWhite.features.values.forEach((v) => expect(v, equals(0.0)));

      expect(resLowContrast.staticHandwritingScore, equals(0.0));
      resLowContrast.features.values.forEach((v) => expect(v, equals(0.0)));
      print('----------------------------------\n');
    });
  });

  group('Step 5: Manual Cross-Check of One Feature', () {
    test('Perform manual calculation verify', () {
      // Define a simple 3-point stroke
      // p0 = (0.0, 0.0, t=0)
      // p1 = (3.0, 4.0, t=10)
      // p2 = (6.0, 12.0, t=30)
      final pts = [
        const StrokePoint(x: 0.0, y: 0.0, timestamp: 0, pressure: 0.5),
        const StrokePoint(x: 3.0, y: 4.0, timestamp: 10, pressure: 0.5),
        const StrokePoint(x: 6.0, y: 12.0, timestamp: 30, pressure: 0.5),
      ];
      final stroke = Stroke(
        points: pts,
        penDownTime: 0,
        penUpTime: 30,
      );

      final sp = computeSpatialFeatures([stroke]);
      final dy = computeDynamicFeatures([stroke]);

      print('\n--- MANUAL CROSS-CHECK ---');
      print('Raw Points:');
      for (int i = 0; i < pts.length; i++) {
        print('  Point $i: (x: ${pts[i].x}, y: ${pts[i].y}, t: ${pts[i].timestamp})');
      }
      print('Computed Spatial features:');
      print('  stroke_length: ${sp['stroke_length']}');
      print('Computed Dynamic features:');
      print('  mean_velocity: ${dy['mean_velocity']}');
      
      // Verification assertion
      // d1 = sqrt((3-0)^2 + (4-0)^2) = 5.0
      // d2 = sqrt((6-3)^2 + (12-4)^2) = sqrt(9 + 64) = sqrt(73) ≈ 8.544003745
      // Expected stroke_length = 13.544003745
      // v1 = 5.0 / 10.0 = 0.5
      // v2 = 8.544003745 / 20.0 = 0.427200187
      // Expected mean_velocity = (0.5 + 0.427200187) / 2 = 0.463600093
      expect(sp['stroke_length'], closeTo(13.5440037, 1e-6));
      expect(dy['mean_velocity'], closeTo(0.46360009, 1e-6));
      print('--------------------------\n');
    });
  });
}
