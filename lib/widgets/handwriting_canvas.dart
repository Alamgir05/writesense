import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stroke_point.dart';
import '../providers/session_provider.dart';

/// The live handwriting capture canvas.
/// Uses [Listener] to get raw [PointerEvent]s including pressure data.
/// Paints strokes in real-time via [CustomPainter].
class HandwritingCanvas extends ConsumerWidget {
  final Color strokeColor;
  final double strokeWidth;

  const HandwritingCanvas({
    super.key,
    this.strokeColor = const Color(0xFF1A1A2E),
    this.strokeWidth = 3.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawState = ref.watch(drawingProvider);
    final notifier = ref.read(drawingProvider.notifier);

    return Listener(
      onPointerDown: (event) {
        final point = StrokePoint(
          x: event.localPosition.dx,
          y: event.localPosition.dy,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          pressure: event.pressure.clamp(0.0, 1.0),
        );
        notifier.startStroke(point);
      },
      onPointerMove: (event) {
        final point = StrokePoint(
          x: event.localPosition.dx,
          y: event.localPosition.dy,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          pressure: event.pressure.clamp(0.0, 1.0),
        );
        notifier.addPoint(point);
      },
      onPointerUp: (event) {
        notifier.endStroke(DateTime.now().millisecondsSinceEpoch);
      },
      onPointerCancel: (event) {
        notifier.endStroke(DateTime.now().millisecondsSinceEpoch);
      },
      child: CustomPaint(
        // foregroundPainter draws ON TOP of the white child Container
        // (painter would draw behind it, making strokes invisible)
        foregroundPainter: _StrokePainter(
          completedStrokes: drawState.completedStrokes,
          activeStroke: drawState.activeStroke,
          strokeColor: strokeColor,
          strokeWidth: strokeWidth,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List completedStrokes;
  final dynamic activeStroke;
  final Color strokeColor;
  final double strokeWidth;

  _StrokePainter({
    required this.completedStrokes,
    required this.activeStroke,
    required this.strokeColor,
    required this.strokeWidth,
  });

  final _paint = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed strokes
    for (final stroke in completedStrokes) {
      _drawStroke(canvas, stroke.points, 1.0);
    }
    // Draw active (in-progress) stroke
    if (activeStroke != null && activeStroke!.points.isNotEmpty) {
      _drawStroke(canvas, activeStroke!.points, 1.0);
    }
  }

  void _drawStroke(Canvas canvas, List points, double opacity) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      // Single dot
      final p = points.first;
      _paint
        ..color = strokeColor.withValues(alpha: opacity)
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(Offset(p.x, p.y), strokeWidth / 2, _paint);
      return;
    }

    for (int i = 1; i < points.length; i++) {
      // Use pressure to vary stroke width slightly
      final pressure = points[i].pressure;
      final width = strokeWidth * (0.7 + pressure * 0.6);
      _paint
        ..color = strokeColor.withValues(alpha: opacity)
        ..strokeWidth = width;

      if (i < points.length - 1) {
        // Smooth cubic bezier through midpoints for natural feel
        final mid = Offset(
          (points[i].x + points[i - 1].x) / 2,
          (points[i].y + points[i - 1].y) / 2,
        );
        canvas.drawLine(
          Offset(points[i - 1].x, points[i - 1].y),
          mid,
          _paint,
        );
      } else {
        canvas.drawLine(
          Offset(points[i - 1].x, points[i - 1].y),
          Offset(points[i].x, points[i].y),
          _paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StrokePainter old) => true;
}
