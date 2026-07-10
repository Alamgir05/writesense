import 'dart:convert';
import 'stroke_point.dart';

/// A single continuous pen-down segment (finger/stylus touches → lifts).
class Stroke {
  final List<StrokePoint> points;
  final int penDownTime; // epoch ms
  final int penUpTime;   // epoch ms

  const Stroke({
    required this.points,
    required this.penDownTime,
    required this.penUpTime,
  });

  /// Duration the pen was down for this stroke.
  Duration get duration =>
      Duration(milliseconds: (penUpTime - penDownTime).abs());

  /// Whether this stroke has enough points to compute features.
  bool get isValid => points.length >= 2;

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'penDown': penDownTime,
        'penUp': penUpTime,
      };

  factory Stroke.fromJson(Map<String, dynamic> json) => Stroke(
        points: (json['points'] as List)
            .map((p) => StrokePoint.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
        penDownTime: json['penDown'] as int,
        penUpTime: json['penUp'] as int,
      );

  /// Encode a list of strokes to a JSON string for DB storage.
  static String encodeList(List<Stroke> strokes) =>
      jsonEncode(strokes.map((s) => s.toJson()).toList());

  /// Decode a JSON string back to a list of strokes.
  static List<Stroke> decodeList(String json) =>
      (jsonDecode(json) as List)
          .map((s) => Stroke.fromJson(Map<String, dynamic>.from(s)))
          .toList();
}
