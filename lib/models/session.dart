import 'dart:convert';
import 'stroke.dart';

/// Represents a complete handwriting capture session.
/// Contains all strokes, computed features, and classification result.
class Session {
  final String id;
  final DateTime timestamp;
  final List<Stroke> strokes;
  final Map<String, double> features;
  final double irregularityIndex; // 0.0 (regular) → 1.0 (irregular)
  final String classification;    // "Regular" | "Irregular"

  const Session({
    required this.id,
    required this.timestamp,
    required this.strokes,
    required this.features,
    required this.irregularityIndex,
    required this.classification,
  });

  int get totalPoints =>
      strokes.fold(0, (sum, s) => sum + s.points.length);

  int get strokeCount => strokes.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'features': features,
        'irregularityIndex': irregularityIndex,
        'classification': classification,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
        strokes: (json['strokes'] as List)
            .map((s) => Stroke.fromJson(Map<String, dynamic>.from(s)))
            .toList(),
        features: Map<String, double>.from(
          (json['features'] as Map).map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          ),
        ),
        irregularityIndex: (json['irregularityIndex'] as num).toDouble(),
        classification: json['classification'] as String,
      );

  /// For SQLite: convert features map to JSON string.
  String get featuresJson => jsonEncode(features);

  /// For SQLite: convert strokes to JSON string.
  String get strokesJson => Stroke.encodeList(strokes);

  /// Reconstruct from SQLite row map.
  factory Session.fromDbRow(Map<String, dynamic> row) => Session(
        id: row['id'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
        strokes: Stroke.decodeList(row['strokes_json'] as String),
        features: Map<String, double>.from(
          (jsonDecode(row['features_json'] as String) as Map).map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          ),
        ),
        irregularityIndex: (row['irregularity_index'] as num).toDouble(),
        classification: row['classification'] as String,
      );
}
