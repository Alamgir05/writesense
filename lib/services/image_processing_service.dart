import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Holds the output of the image analysis.
class ImageAnalysisResult {
  final Map<String, double> features;
  final double staticHandwritingScore;

  const ImageAnalysisResult({
    required this.features,
    required this.staticHandwritingScore,
  });
}

/// A simple representation of a 2D pixel coordinate.
class _PixelPoint {
  final int x;
  final int y;
  const _PixelPoint(this.x, this.y);
}

class ImageProcessingService {
  /// Entry point: analyzes [imageBytes] and returns the extracted features and score.
  Future<ImageAnalysisResult> analyzeImage(Uint8List imageBytes) async {
    try {
      // 1. Decode image
      final rawImg = img.decodeImage(imageBytes);
      if (rawImg == null) {
        return _emptyResult();
      }

      // 2. Resize to maximum dimension of 600px for speed and memory efficiency
      img.Image processedImg = rawImg;
      if (processedImg.width > 600 || processedImg.height > 600) {
        final double aspectRatio = processedImg.width / processedImg.height;
        int newWidth, newHeight;
        if (processedImg.width > processedImg.height) {
          newWidth = 600;
          newHeight = (600 / aspectRatio).round();
        } else {
          newHeight = 600;
          newWidth = (600 * aspectRatio).round();
        }
        processedImg = img.copyResize(processedImg, width: newWidth, height: newHeight);
      }

      final w = processedImg.width;
      final h = processedImg.height;
      if (w <= 0 || h <= 0) {
        return _emptyResult();
      }

      // 3. Grayscale conversion
      final grayImg = img.grayscale(processedImg);

      // 4. Integral image calculation for O(1) local mean extraction
      final integral = List.generate(h + 1, (_) => Int32List(w + 1));
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final pixel = grayImg.getPixel(x, y);
          final val = pixel.r.toInt();
          integral[y + 1][x + 1] = val +
              integral[y][x + 1] +
              integral[y + 1][x] -
              integral[y][x];
        }
      }

      // 5. Adaptive local thresholding
      // Window size: 31x31 (radius = 15). Threshold constant C = 15.
      const r = 15;
      const c = 15;
      final binary = List.generate(h, (_) => Uint8List(w));
      int totalInkPixels = 0;

      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final y1 = (y - r).clamp(0, h - 1);
          final y2 = (y + r).clamp(0, h - 1);
          final x1 = (x - r).clamp(0, w - 1);
          final x2 = (x + r).clamp(0, w - 1);

          final count = (y2 - y1 + 1) * (x2 - x1 + 1);
          final sum = integral[y2 + 1][x2 + 1] -
              integral[y1][x2 + 1] -
              integral[y2 + 1][x1] +
              integral[y1][x1];
          final mean = sum / count;

          final val = grayImg.getPixel(x, y).r.toInt();
          // If the pixel is significantly darker than its local neighborhood, it's ink (1)
          if (val < (mean - c)) {
            binary[y][x] = 1;
            totalInkPixels++;
          } else {
            binary[y][x] = 0;
          }
        }
      }

      if (totalInkPixels == 0) {
        return _emptyResult();
      }

      // 6. Connected Component Labeling (CCL) using BFS (8-connectivity)
      final visited = List.generate(h, (_) => Uint8List(w));
      final List<List<_PixelPoint>> components = [];

      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          if (binary[y][x] == 1 && visited[y][x] == 0) {
            final List<_PixelPoint> comp = [];
            final queue = Queue<_PixelPoint>();

            queue.add(_PixelPoint(x, y));
            visited[y][x] = 1;

            while (queue.isNotEmpty) {
              final curr = queue.removeFirst();
              comp.add(curr);

              for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                  if (dx == 0 && dy == 0) continue;
                  final ny = curr.y + dy;
                  final nx = curr.x + dx;
                  if (ny >= 0 && ny < h && nx >= 0 && nx < w) {
                    if (binary[ny][nx] == 1 && visited[ny][nx] == 0) {
                      visited[ny][nx] = 1;
                      queue.add(_PixelPoint(nx, ny));
                    }
                  }
                }
              }
            }

            // Keep components of size > 5 to discard small noise
            if (comp.length > 5) {
              components.add(comp);
            }
          }
        }
      }

      if (components.isEmpty) {
        return _emptyResult();
      }

      // 7. Distance Transform (2-pass Manhattan Distance) to estimate stroke width
      final dist = List.generate(h, (_) => Float32List(w));
      const maxDist = 999999.0;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          if (binary[y][x] == 0) {
            dist[y][x] = 0.0;
          } else {
            final top = (y > 0) ? dist[y - 1][x] : maxDist;
            final left = (x > 0) ? dist[y][x - 1] : maxDist;
            dist[y][x] = 1.0 + min(top, left);
          }
        }
      }
      for (int y = h - 1; y >= 0; y--) {
        for (int x = w - 1; x >= 0; x--) {
          if (binary[y][x] == 1) {
            final bottom = (y < h - 1) ? dist[y + 1][x] : maxDist;
            final right = (x < w - 1) ? dist[y][x + 1] : maxDist;
            final current = dist[y][x];
            final minNeighbor = 1.0 + min(bottom, right);
            dist[y][x] = min(current, minNeighbor);
          }
        }
      }

      // 8. Feature Extraction: Stroke Width (average & variance)
      final List<double> strokeWidths = [];
      for (final comp in components) {
        double maxCompDist = 0.0;
        final List<double> compWidths = [];
        for (final p in comp) {
          final d = dist[p.y][p.x];
          if (d > maxCompDist) maxCompDist = d;

          // Local maximum check in 8-neighborhood (skeleton estimation)
          bool isLocalMax = true;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              final ny = p.y + dy;
              final nx = p.x + dx;
              if (ny >= 0 && ny < h && nx >= 0 && nx < w) {
                if (dist[ny][nx] > d) {
                  isLocalMax = false;
                  break;
                }
              }
            }
            if (!isLocalMax) break;
          }
          if (isLocalMax) {
            compWidths.add(2.0 * d);
          }
        }
        if (compWidths.isEmpty) {
          strokeWidths.add(2.0 * maxCompDist);
        } else {
          strokeWidths.addAll(compWidths);
        }
      }
      final widthStats = _computeStats(strokeWidths);
      final avgStrokeWidth = widthStats['mean']!;
      final strokeWidthVar = widthStats['variance']!;

      // 9. Feature Extraction: Ink Density
      final double inkDensity = totalInkPixels / (w * h);

      // 10. Feature Extraction: Slant Angle (average & variance)
      final List<double> slantAngles = [];
      for (final comp in components) {
        final m00 = comp.length.toDouble();
        double sumX = 0.0;
        double sumY = 0.0;
        for (final p in comp) {
          sumX += p.x;
          sumY += p.y;
        }
        final cx = sumX / m00;
        final cy = sumY / m00;

        double mu20 = 0.0;
        double mu02 = 0.0;
        double mu11 = 0.0;
        for (final p in comp) {
          final dx = p.x - cx;
          final dy = p.y - cy;
          mu20 += dx * dx;
          mu02 += dy * dy;
          mu11 += dx * dy;
        }

        final theta = 0.5 * atan2(2.0 * mu11, mu20 - mu02);
        // Map from radians to degrees
        final thetaDeg = (theta * 180.0 / pi).clamp(-90.0, 90.0);
        slantAngles.add(thetaDeg);
      }
      final slantStats = _computeStats(slantAngles);
      final avgSlant = slantStats['mean']!;
      final slantVar = slantStats['variance']!;

      // 11. Feature Extraction: Line Spacing (mean & variance) via vertical projection profile
      final yProj = List<double>.filled(h, 0.0);
      for (int y = 0; y < h; y++) {
        int rowSum = 0;
        for (int x = 0; x < w; x++) {
          if (binary[y][x] == 1) rowSum++;
        }
        yProj[y] = rowSum.toDouble();
      }

      // Smooth vertical projection profile
      final smoothedYProj = List<double>.filled(h, 0.0);
      const win = 7;
      for (int y = 0; y < h; y++) {
        double sum = 0.0;
        int count = 0;
        for (int dy = -win; dy <= win; dy++) {
          final ny = y + dy;
          if (ny >= 0 && ny < h) {
            sum += yProj[ny];
            count++;
          }
        }
        smoothedYProj[y] = sum / count;
      }

      final double meanSmoothedY = smoothedYProj.reduce((a, b) => a + b) / h;
      final List<int> yPeaks = [];
      for (int y = 1; y < h - 1; y++) {
        if (smoothedYProj[y] > smoothedYProj[y - 1] &&
            smoothedYProj[y] > smoothedYProj[y + 1] &&
            smoothedYProj[y] > meanSmoothedY * 0.5) {
          yPeaks.add(y);
        }
      }

      final List<double> lineGaps = [];
      for (int i = 1; i < yPeaks.length; i++) {
        lineGaps.add((yPeaks[i] - yPeaks[i - 1]).toDouble());
      }
      final lineStats = _computeStats(lineGaps);
      final lineSpacingMean = lineStats['mean']!;
      final lineSpacingVar = lineStats['variance']!;

      // 12. Feature Extraction: Word/Character Spacing (mean & variance) via horizontal overlaps
      final List<double> horizontalGaps = [];
      // Calculate bounds for components
      final List<_ComponentBounds> boundsList = components.map((comp) {
        int minX = w, maxX = 0, minY = h, maxY = 0;
        for (final p in comp) {
          if (p.x < minX) minX = p.x;
          if (p.x > maxX) maxX = p.x;
          if (p.y < minY) minY = p.y;
          if (p.y > maxY) maxY = p.y;
        }
        return _ComponentBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY);
      }).toList();

      // Sort by minX
      boundsList.sort((a, b) => a.minX.compareTo(b.minX));

      for (int i = 0; i < boundsList.length; i++) {
        final bi = boundsList[i];
        for (int j = i + 1; j < boundsList.length; j++) {
          final bj = boundsList[j];
          // Check vertical overlap
          final overlap = (bi.minY < bj.maxY) && (bj.minY < bi.maxY);
          if (overlap) {
            final gap = bj.minX - bi.maxX;
            if (gap > 0) {
              horizontalGaps.add(gap.toDouble());
              break; // Nearest overlap to the right
            }
          }
        }
      }
      final wordStats = _computeStats(horizontalGaps);
      final wordSpacingMean = wordStats['mean']!;
      final wordSpacingVar = wordStats['variance']!;

      // 13. Feature Extraction: Baseline Deviation
      double baselineDev = 0.0;
      if (boundsList.length >= 2) {
        double sumX = 0.0;
        double sumY = 0.0;
        for (final b in boundsList) {
          final cx = (b.minX + b.maxX) / 2.0;
          sumX += cx;
          sumY += b.maxY;
        }
        final meanX = sumX / boundsList.length;
        final meanY = sumY / boundsList.length;

        double num = 0.0;
        double den = 0.0;
        for (final b in boundsList) {
          final cx = (b.minX + b.maxX) / 2.0;
          final dx = cx - meanX;
          final dy = b.maxY - meanY;
          num += dx * dy;
          den += dx * dx;
        }

        final double slope = (den != 0.0) ? (num / den) : 0.0;
        final double intercept = meanY - slope * meanX;

        double sumSqErr = 0.0;
        for (final b in boundsList) {
          final cx = (b.minX + b.maxX) / 2.0;
          final expectedY = slope * cx + intercept;
          final err = b.maxY - expectedY;
          sumSqErr += err * err;
        }
        baselineDev = sqrt(sumSqErr / boundsList.length);
      }

      // 14. Weighted static irregularity score
      // Normalize values to [0, 1] based on reasonable upper limits.
      final nBaselineDev = (baselineDev / 40.0).clamp(0.0, 1.0);
      final nStrokeWidthVar = (strokeWidthVar / 5.0).clamp(0.0, 1.0);
      final nSlantVar = (slantVar / 45.0).clamp(0.0, 1.0);
      final nLineSpacingVar = (lineSpacingVar / 20.0).clamp(0.0, 1.0);
      final nWordSpacingVar = (wordSpacingVar / 30.0).clamp(0.0, 1.0);

      // Placeholder weights adding up to 1.0
      const wBaselineDev = 0.30;
      const wStrokeWidthVar = 0.20;
      const wSlantVariance = 0.20;
      const wLineSpacingVar = 0.15;
      const wWordSpacingVar = 0.15;

      final staticHandwritingScore = (wBaselineDev * nBaselineDev +
              wStrokeWidthVar * nStrokeWidthVar +
              wSlantVariance * nSlantVar +
              wLineSpacingVar * nLineSpacingVar +
              wWordSpacingVar * nWordSpacingVar)
          .clamp(0.0, 1.0);

      final Map<String, double> finalFeatures = {
        'average_stroke_width': _safe(avgStrokeWidth),
        'stroke_width_variance': _safe(strokeWidthVar),
        'ink_density': _safe(inkDensity),
        'average_slant_angle': _safe(avgSlant),
        'slant_angle_variance': _safe(slantVar),
        'line_spacing': _safe(lineSpacingMean),
        'line_spacing_variance': _safe(lineSpacingVar),
        'word_spacing': _safe(wordSpacingMean),
        'word_spacing_variance': _safe(wordSpacingVar),
        'baseline_deviation': _safe(baselineDev),
      };

      return ImageAnalysisResult(
        features: finalFeatures,
        staticHandwritingScore: _safe(staticHandwritingScore),
      );
    } catch (_) {
      // Fallback on any unexpected error
      return _emptyResult();
    }
  }

  /// Safe helper to compute mean and variance.
  Map<String, double> _computeStats(List<double> values) {
    if (values.isEmpty) return {'mean': 0.0, 'variance': 0.0};
    final mean = values.reduce((a, b) => a + b) / values.length;
    double sumSqDiff = 0.0;
    for (final v in values) {
      sumSqDiff += (v - mean) * (v - mean);
    }
    final variance = sumSqDiff / values.length;
    return {
      'mean': _safe(mean),
      'variance': _safe(variance),
    };
  }

  double _safe(double v) => (v.isNaN || v.isInfinite) ? 0.0 : v;

  ImageAnalysisResult _emptyResult() {
    return const ImageAnalysisResult(
      features: {
        'average_stroke_width': 0.0,
        'stroke_width_variance': 0.0,
        'ink_density': 0.0,
        'average_slant_angle': 0.0,
        'slant_angle_variance': 0.0,
        'line_spacing': 0.0,
        'line_spacing_variance': 0.0,
        'word_spacing': 0.0,
        'word_spacing_variance': 0.0,
        'baseline_deviation': 0.0,
      },
      staticHandwritingScore: 0.0,
    );
  }
}

class _ComponentBounds {
  final int minX;
  final int maxX;
  final int minY;
  final int maxY;

  const _ComponentBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });
}
