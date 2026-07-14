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
  group('Regression Check A: 5-Stroke Extreme Spread', () {
    test('Evaluate 5 extreme profiles', () {
      final random = math.Random(101);
      final List<Stroke> strokes = [];

      // 1. Perfectly Straight
      final List<StrokePoint> pts1 = [];
      for (int i = 0; i <= 40; i++) {
        final t = i * 25;
        final double x = 200.0 * (t / 1000.0);
        final double y = 50.0;
        pts1.add(StrokePoint(x: x, y: y, timestamp: t, pressure: 0.5));
      }
      strokes.add(Stroke(points: pts1, penDownTime: 0, penUpTime: 1000));

      // 2. Slightly Wavy
      final List<StrokePoint> pts2 = [];
      for (int i = 0; i <= 40; i++) {
        final t = i * 25;
        final double x = 200.0 * (t / 1000.0);
        final double y = 50.0 + 3.0 * math.sin(2.0 * math.pi * 1.0 * (t / 1000.0));
        pts2.add(StrokePoint(x: x, y: y, timestamp: t, pressure: 0.5));
      }
      strokes.add(Stroke(points: pts2, penDownTime: 0, penUpTime: 1000));

      // 3. Moderately Wavy
      final List<StrokePoint> pts3 = [];
      for (int i = 0; i <= 40; i++) {
        final t = i * 25;
        final double x = 200.0 * (t / 1000.0);
        final double y = 50.0 + 8.0 * math.sin(2.0 * math.pi * 2.0 * (t / 1000.0));
        pts3.add(StrokePoint(x: x, y: y, timestamp: t, pressure: 0.5));
      }
      strokes.add(Stroke(points: pts3, penDownTime: 0, penUpTime: 1000));

      // 4. Very Wavy/Jittery
      final List<StrokePoint> pts4 = [];
      for (int i = 0; i <= 40; i++) {
        final t = i * 25;
        final double x = 200.0 * (t / 1000.0);
        final double jitter = (random.nextDouble() - 0.5) * 8.0;
        final double y = 50.0 + 15.0 * math.sin(2.0 * math.pi * 3.0 * (t / 1000.0)) + jitter;
        pts4.add(StrokePoint(x: x, y: y, timestamp: t, pressure: 0.5));
      }
      strokes.add(Stroke(points: pts4, penDownTime: 0, penUpTime: 1000));

      // 5. Extreme Tremor/Jitter (Parkinsonian 5 Hz)
      final List<StrokePoint> pts5 = [];
      for (int i = 0; i <= 40; i++) {
        final t = i * 25;
        final double x = 200.0 * (t / 1000.0) + 6.0 * math.sin(2.0 * math.pi * 5.0 * (t / 1000.0) + math.pi/4);
        final double jitter = (random.nextDouble() - 0.5) * 12.0;
        final double y = 50.0 + 15.0 * math.sin(2.0 * math.pi * 5.0 * (t / 1000.0)) + jitter;
        pts5.add(StrokePoint(x: x, y: y, timestamp: t, pressure: 0.5));
      }
      strokes.add(Stroke(points: pts5, penDownTime: 0, penUpTime: 1000));

      print('\n=== REGRESSION CHECK A: 5-STROKE EXTREME SPREAD ===');
      for (int k = 0; k < 5; k++) {
        final s = strokes[k];
        final sp = computeSpatialFeatures([s]);
        final tm = computeTemporalFeatures([s]);
        final dy = computeDynamicFeatures([s]);
        final sc = computeFluencyScores(spatial: sp, temporal: tm, dynamic_: dy, strokeCount: 1);
        final score = sc['irregularity_index']!;
        print('  Stroke ${k + 1}: Score = ${score.toStringAsFixed(4)} (${classify(score)})');
      }
      print('===================================================\n');
    });
  });

  group('Regression Check B: 3-Stroke Normal Handwriting Spread', () {
    test('Evaluate 3 normal handwriting profiles', () {
      final List<Stroke> normalStrokes = [];

      // Normal 1: Low-frequency, low-amplitude minor waviness
      final List<StrokePoint> pts1 = [];
      for (int i = 0; i <= 40; i++) {
        final t = i * 25;
        final double x = 200.0 * (t / 1000.0);
        final double y = 50.0 + 1.0 * math.sin(2.0 * math.pi * 1.0 * (t / 1000.0));
        pts1.add(StrokePoint(x: x, y: y, timestamp: t, pressure: 0.5));
      }
      normalStrokes.add(Stroke(points: pts1, penDownTime: 0, penUpTime: 1000));

      // Normal 2: Superimposition of two gentle frequencies, no jitter
      final List<StrokePoint> pts2 = [];
      for (int i = 0; i <= 40; i++) {
        final t = i * 25;
        final double x = 200.0 * (t / 1000.0);
        final double y = 50.0 + 1.5 * math.sin(2.0 * math.pi * 0.5 * (t / 1000.0)) + 0.5 * math.cos(2.0 * math.pi * 1.5 * (t / 1000.0));
        pts2.add(StrokePoint(x: x, y: y, timestamp: t, pressure: 0.5));
      }
      normalStrokes.add(Stroke(points: pts2, penDownTime: 0, penUpTime: 1000));

      // Normal 3: Slow baseline curve / natural handwriting arc
      final List<StrokePoint> pts3 = [];
      for (int i = 0; i <= 40; i++) {
        final t = i * 25;
        final double x = 200.0 * (t / 1000.0);
        final double y = 50.0 + 4.0 * math.sin(math.pi * (t / 1000.0));
        pts3.add(StrokePoint(x: x, y: y, timestamp: t, pressure: 0.5));
      }
      normalStrokes.add(Stroke(points: pts3, penDownTime: 0, penUpTime: 1000));

      print('\n=== REGRESSION CHECK B: 3-STROKE NORMAL SPREAD ===');
      for (int k = 0; k < 3; k++) {
        final s = normalStrokes[k];
        final sp = computeSpatialFeatures([s]);
        final tm = computeTemporalFeatures([s]);
        final dy = computeDynamicFeatures([s]);
        final sc = computeFluencyScores(spatial: sp, temporal: tm, dynamic_: dy, strokeCount: 1);
        final score = sc['irregularity_index']!;
        print('  Normal Stroke ${k + 1}: Score = ${score.toStringAsFixed(4)} (${classify(score)})');
        
        // Assert they land in Regular
        expect(score, lessThan(0.35), reason: 'Normal Stroke ${k + 1} scored as irregular ($score)');
      }
      print('==================================================\n');
    });
  });

  group('Regression Check D: Image Quality Gate on Clean vs Shadowed', () {
    test('Verify quality gate triggering', () async {
      final service = ImageProcessingService();
      
      // Clean image
      final cleanFile = File('handwriting_sample.png');
      final cleanBytes = await cleanFile.readAsBytes();
      final cleanRes = await service.analyzeImage(cleanBytes);
      
      // Shadowed & blurred image
      final originalImage = img.decodeImage(cleanBytes)!;
      final w = originalImage.width;
      final h = originalImage.height;
      final lowLightImage = img.Image(width: w, height: h);
      
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final pixel = originalImage.getPixel(x, y);
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          final double gradientFactor = 0.15 + 0.35 * (x / w);
          final nr = (r * gradientFactor).round().clamp(0, 255);
          final ng = (g * gradientFactor).round().clamp(0, 255);
          final nb = (b * gradientFactor).round().clamp(0, 255);
          lowLightImage.setPixel(x, y, img.ColorRgb8(nr, ng, nb));
        }
      }
      final blurredLowLight = img.gaussianBlur(lowLightImage, radius: 2);
      final processedBytes = Uint8List.fromList(img.encodePng(blurredLowLight));
      final shadowedRes = await service.analyzeImage(processedBytes);
      
      print('\n=== REGRESSION CHECK D: IMAGE QUALITY GATE ===');
      print('Clean Image:');
      print('  Score: ${cleanRes.staticHandwritingScore}');
      print('  isLowConfidence: ${cleanRes.isLowConfidence}');
      print('  confidenceMessage: ${cleanRes.confidenceMessage}');
      print('  ink_density: ${cleanRes.features['ink_density']}');
      
      print('Shadowed & Blurry Image:');
      print('  Score: ${shadowedRes.staticHandwritingScore}');
      print('  isLowConfidence: ${shadowedRes.isLowConfidence}');
      print('  confidenceMessage: ${shadowedRes.confidenceMessage}');
      print('  ink_density: ${shadowedRes.features['ink_density']}');
      print('==============================================\n');
      
      // Assertions
      expect(cleanRes.isLowConfidence, false, reason: 'Clean image should not trigger quality gate');
      expect(shadowedRes.isLowConfidence, true, reason: 'Shadowed image should trigger quality gate');
      expect(shadowedRes.staticHandwritingScore, 0.0);
    });
  });
}
