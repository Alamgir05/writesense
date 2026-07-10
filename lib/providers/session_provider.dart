import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stroke.dart';
import '../models/stroke_point.dart';
import '../models/session.dart';
import '../features/spatial_features.dart';
import '../features/temporal_features.dart';
import '../features/dynamic_features.dart';
import '../features/fluency_score.dart';
import '../services/session_repository.dart';
import 'package:uuid/uuid.dart';

// ── Drawing state ─────────────────────────────────────────────────────────

class DrawingNotifier extends StateNotifier<DrawingState> {
  DrawingNotifier() : super(DrawingState.empty());

  void startStroke(StrokePoint point) {
    final newStroke = ActiveStroke(
      points: [point],
      penDownTime: point.timestamp,
    );
    state = state.copyWith(activeStroke: newStroke);
  }

  void addPoint(StrokePoint point) {
    final active = state.activeStroke;
    if (active == null) return;
    state = state.copyWith(
      activeStroke: active.copyWith(points: [...active.points, point]),
    );
  }

  void endStroke(int penUpTime) {
    final active = state.activeStroke;
    if (active == null || active.points.isEmpty) return;
    final stroke = Stroke(
      points: active.points,
      penDownTime: active.penDownTime,
      penUpTime: penUpTime,
    );
    state = state.copyWith(
      completedStrokes: [...state.completedStrokes, stroke],
      activeStroke: null,
    );
  }

  void clear() => state = DrawingState.empty();

  /// Run feature extraction and return a [Session]. Also persists to DB.
  Future<Session> analyzeAndSave(SessionRepository repo) async {
    final strokes = state.completedStrokes;

    // Compute feature families
    final spatial = computeSpatialFeatures(strokes);
    final temporal = computeTemporalFeatures(strokes);
    final dynamic_ = computeDynamicFeatures(strokes);
    final fluency = computeFluencyScores(
      spatial: spatial,
      temporal: temporal,
      dynamic_: dynamic_,
    );

    // Merge all features into one map
    final allFeatures = <String, double>{
      ...spatial,
      ...temporal,
      ...dynamic_,
      ...fluency,
    };

    final index = fluency['irregularity_index'] ?? 0.0;
    final session = Session(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      strokes: strokes,
      features: allFeatures,
      irregularityIndex: index,
      classification: classify(index),
    );

    await repo.insertSession(session);
    return session;
  }
}

class DrawingState {
  final List<Stroke> completedStrokes;
  final ActiveStroke? activeStroke;

  const DrawingState({
    required this.completedStrokes,
    this.activeStroke,
  });

  factory DrawingState.empty() =>
      const DrawingState(completedStrokes: []);

  DrawingState copyWith({
    List<Stroke>? completedStrokes,
    ActiveStroke? activeStroke,
    bool clearActive = false,
  }) =>
      DrawingState(
        completedStrokes: completedStrokes ?? this.completedStrokes,
        activeStroke: clearActive ? null : (activeStroke ?? this.activeStroke),
      );

  bool get isEmpty =>
      completedStrokes.isEmpty && (activeStroke == null || activeStroke!.points.isEmpty);
}

class ActiveStroke {
  final List<StrokePoint> points;
  final int penDownTime;

  const ActiveStroke({required this.points, required this.penDownTime});

  ActiveStroke copyWith({List<StrokePoint>? points}) =>
      ActiveStroke(points: points ?? this.points, penDownTime: penDownTime);
}

// ── Providers ─────────────────────────────────────────────────────────────

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(),
);

final drawingProvider =
    StateNotifierProvider<DrawingNotifier, DrawingState>(
  (ref) => DrawingNotifier(),
);
