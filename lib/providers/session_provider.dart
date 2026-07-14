import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/session.dart';
import '../models/stroke.dart';
import '../models/stroke_point.dart';
import '../features/spatial_features.dart';
import '../features/temporal_features.dart';
import '../features/dynamic_features.dart';
import '../features/fluency_score.dart';
import '../services/firestore_service.dart';

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

  /// Run feature extraction and return a [Session]. Also persists to Firestore.
  Future<Session> analyzeAndSave(FirestoreService firestore) async {
    final strokes = state.completedStrokes;
    final spatial  = computeSpatialFeatures(strokes);
    final temporal = computeTemporalFeatures(strokes);
    final dynamic_ = computeDynamicFeatures(strokes);
    final fluency  = computeFluencyScores(
      spatial: spatial,
      temporal: temporal,
      dynamic_: dynamic_,
      strokeCount: strokes.length,
    );
    final allFeatures = <String, double>{
      ...spatial, ...temporal, ...dynamic_, ...fluency,
    };
    final index = fluency['irregularity_index'] ?? 0.0;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final session = Session(
      id:               const Uuid().v4(),
      userId:           uid,
      timestamp:        DateTime.now(),
      source:           SessionSource.tablet,
      strokes:          strokes,
      features:         allFeatures,
      irregularityIndex: index,
      classification:   classify(index),
    );
    await firestore.saveSession(session).timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        // If it takes more than 2 seconds (e.g. offline/poor connection),
        // let the UI proceed. Firestore will automatically sync it in the background.
        print("Firestore save timed out. Syncing in background.");
      },
    );
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

final firestoreProvider = Provider<FirestoreService>((ref) => FirestoreService());

final drawingProvider =
    StateNotifierProvider<DrawingNotifier, DrawingState>(
  (ref) => DrawingNotifier(),
);
