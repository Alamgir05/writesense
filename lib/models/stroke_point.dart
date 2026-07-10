/// A single captured point during handwriting.
/// [x], [y] are in logical pixels (local to the canvas).
/// [timestamp] is milliseconds since epoch.
/// [pressure] is 0.0–1.0; defaults to 0.5 when device doesn't report pressure.
class StrokePoint {
  final double x;
  final double y;
  final int timestamp;
  final double pressure;

  const StrokePoint({
    required this.x,
    required this.y,
    required this.timestamp,
    this.pressure = 0.5,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        't': timestamp,
        'p': pressure,
      };

  factory StrokePoint.fromJson(Map<String, dynamic> json) => StrokePoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        timestamp: json['t'] as int,
        pressure: (json['p'] as num?)?.toDouble() ?? 0.5,
      );

  @override
  String toString() =>
      'StrokePoint(x: ${x.toStringAsFixed(1)}, y: ${y.toStringAsFixed(1)}, t: $timestamp, p: ${pressure.toStringAsFixed(2)})';
}
