import 'package:flutter/material.dart';

/// A card displaying a group of features (spatial / temporal / dynamic).
class FeatureCard extends StatelessWidget {
  final String title;
  final Map<String, double> features;
  final Color accentColor;

  const FeatureCard({
    super.key,
    required this.title,
    required this.features,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: accentColor.withValues(alpha: 0.15),
          radius: 20,
          child: Icon(_iconForTitle(title), color: accentColor, size: 18),
        ),
        title: Text(
          title,
          style: TextStyle(
              fontWeight: FontWeight.bold, color: accentColor, fontSize: 15),
        ),
        subtitle: Text(
          '${features.length} features',
          style: TextStyle(
              fontSize: 12, color: Theme.of(context).colorScheme.outline),
        ),
        initiallyExpanded: true,
        children: features.entries.map((e) => _featureRow(context, e)).toList(),
      ),
    );
  }

  Widget _featureRow(BuildContext context, MapEntry<String, double> entry) {
    final label = entry.key.replaceAll('_', ' ').replaceFirstMapped(
        RegExp(r'\w'), (m) => m[0]!.toUpperCase());
    final value = entry.value;
    // Normalise for bar display: clamp to common ranges
    final barFraction = _normaliseForDisplay(entry.key, value).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: barFraction,
                    minHeight: 6,
                    backgroundColor:
                        accentColor.withValues(alpha: 0.12),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              _formatValue(entry.key, value),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForTitle(String title) {
    if (title.toLowerCase().contains('spatial')) return Icons.square_foot;
    if (title.toLowerCase().contains('temporal')) return Icons.timer_outlined;
    if (title.toLowerCase().contains('dynamic')) return Icons.speed;
    return Icons.insights;
  }

  String _formatValue(String key, double v) {
    if (key.contains('duration')) return '${v.toStringAsFixed(0)}ms';
    if (key.contains('ratio') || key.contains('score') || key.contains('index')) {
      return '${(v * 100).toStringAsFixed(1)}%';
    }
    if (key.contains('velocity') || key.contains('acceleration') || key.contains('jerk')) {
      return v.toStringAsExponential(2);
    }
    return v.toStringAsFixed(3);
  }

  double _normaliseForDisplay(String key, double v) {
    // Map each feature to a [0,1] display range
    const ranges = <String, double>{
      'stroke_length': 5000,
      'bounding_width': 800,
      'bounding_height': 600,
      'aspect_ratio': 5,
      'mean_slant': 3.14,
      'mean_curvature': 3.14,
      'straightness': 1,
      'writing_density': 0.1,
      'baseline_deviation': 100,
      'center_of_mass_x': 800,
      'center_of_mass_y': 600,
      'total_duration': 30000,
      'pen_down_duration': 20000,
      'pen_down_ratio': 1,
      'pause_count': 20,
      'mean_pause_duration': 3000,
      'writing_tempo': 5,
      'rhythm_regularity': 1,
      'mean_velocity': 2,
      'max_velocity': 10,
      'velocity_variance': 1,
      'mean_acceleration': 0.1,
      'mean_jerk': 0.01,
      'normalized_jerk': 1e6,
      'direction_changes': 200,
      'tremor_frequency': 1,
      'tremor_amplitude': 2,
      'irregularity_index': 1,
      'fluency_score': 1,
      'consistency_score': 1,
    };
    final max = ranges[key] ?? 1.0;
    return max > 0 ? v / max : 0;
  }
}
