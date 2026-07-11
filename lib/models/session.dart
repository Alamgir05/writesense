import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'stroke.dart';

/// Source of a session — determines which features are available.
enum SessionSource {
  tablet, // Full spatial + temporal + kinematic features
  image,  // Spatial-only features (no time dimension)
}

extension SessionSourceX on SessionSource {
  String get label => name; // 'tablet' | 'image'
  static SessionSource fromString(String s) =>
      SessionSource.values.firstWhere((e) => e.name == s,
          orElse: () => SessionSource.tablet);
}

/// Shared session data model for both tablet and image capture.
/// Stored in Firestore at users/{uid}/sessions/{id}.
class Session {
  final String id;
  final String userId;
  final DateTime timestamp;
  final SessionSource source;
  final Map<String, double> features;
  final double irregularityIndex;
  final String classification;

  // Tablet-only fields
  final List<Stroke> strokes;
  final bool? pressureFlat;

  // Image-only fields
  final String? imageUrl;

  const Session({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.source,
    required this.features,
    required this.irregularityIndex,
    required this.classification,
    this.strokes = const [],
    this.pressureFlat,
    this.imageUrl,
  });

  // ── Computed helpers ──────────────────────────────────────────────────────
  int get strokeCount => strokes.length;
  int get totalPoints => strokes.fold(0, (s, st) => s + st.points.length);

  bool get isTablet => source == SessionSource.tablet;
  bool get isImage  => source == SessionSource.image;

  // ── Firestore serialization ───────────────────────────────────────────────
  Map<String, dynamic> toFirestoreMap() => {
    'sessionId':         id,
    'userId':            userId,
    'timestamp':         Timestamp.fromDate(timestamp),
    'source':            source.label,
    'features':          features,
    'irregularityIndex': irregularityIndex,
    'classification':    classification,
    if (strokes.isNotEmpty) 'strokeCount': strokeCount,
    if (strokes.isNotEmpty) 'totalPoints': totalPoints,
    if (pressureFlat != null) 'pressureFlat': pressureFlat,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };

  factory Session.fromFirestoreDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Session(
      id:               doc.id,
      userId:           d['userId'] as String? ?? '',
      timestamp:        (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source:           SessionSourceX.fromString(d['source'] as String? ?? 'tablet'),
      features:         Map<String, double>.from(
                          (d['features'] as Map<String, dynamic>?)?.map(
                            (k, v) => MapEntry(k, (v as num).toDouble()),
                          ) ?? {}),
      irregularityIndex: (d['irregularityIndex'] as num?)?.toDouble() ?? 0.0,
      classification:    d['classification'] as String? ?? 'Unknown',
      pressureFlat:      d['pressureFlat'] as bool?,
      imageUrl:          d['imageUrl'] as String?,
    );
  }

  // ── Legacy SQLite helpers (kept for offline fallback) ─────────────────────
  String get strokesJson => jsonEncode(strokes.map((s) => s.toJson()).toList());
  String get featuresJson => jsonEncode(features);

  factory Session.fromDbRow(Map<String, dynamic> row) {
    final strokesList = (jsonDecode(row['strokes_json'] as String) as List)
        .map((s) => Stroke.fromJson(s as Map<String, dynamic>))
        .toList();
    final featMap = Map<String, double>.from(
        jsonDecode(row['features_json'] as String) as Map<String, dynamic>);
    return Session(
      id:               row['id'] as String,
      userId:           '',
      timestamp:        DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      source:           SessionSourceX.fromString(row['source'] as String? ?? 'tablet'),
      features:         featMap,
      irregularityIndex: (row['irregularity_index'] as num).toDouble(),
      classification:   row['classification'] as String,
      strokes:          strokesList,
    );
  }
}
