import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../services/pdf_report_service.dart';
import '../services/csv_export_service.dart';
import '../widgets/feature_card.dart';
import '../widgets/pressable_scale.dart';

class ResultsScreen extends StatelessWidget {
  final Session session;

  const ResultsScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    if (session.isImage) {
      return _buildImageResults(context);
    }

    final idx = session.irregularityIndex;
    final scoreColor = _scoreColor(idx);
    final spatialFeats = _filter(session.features, _spatialKeys);
    final temporalFeats = _filter(session.features, _temporalKeys);
    final dynamicFeats = _filter(session.features, _dynamicKeys);
    final fluencyFeats = _filter(session.features, _fluencyKeys);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      body: CustomScrollView(
        slivers: [
          // ── Hero app bar ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A18),
            leading: Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: const Color(0xFF1A1A18),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Score gauge
                      _ScoreGauge(index: idx, color: scoreColor),
                      const SizedBox(height: 12),
                      // Classification badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: scoreColor, width: 1.5),
                        ),
                        child: Text(
                          session.classification,
                          style: GoogleFonts.fraunces(
                            color: scoreColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('dd MMM yyyy • HH:mm')
                            .format(session.timestamp),
                        style: GoogleFonts.inter(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (session.isLowConfidence)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFEB2B2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFC53030), size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        session.confidenceMessage ?? 'Low quality or insufficient handwriting detected — result may be unreliable.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9B2C2C),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Export buttons ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ExportButton(
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'Export PDF',
                      color: const Color(0xFFE53E3E),
                      onTap: () async {
                        try {
                          await PdfReportService().exportPdf(session);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('PDF error: $e')));
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ExportButton(
                      icon: Icons.table_chart_rounded,
                      label: 'Export CSV',
                      color: const Color(0xFF38A169),
                      onTap: () async {
                        try {
                          await CsvExportService()
                              .exportFeaturesCSV(session);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('CSV error: $e')));
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ExportButton(
                      icon: Icons.scatter_plot_rounded,
                      label: 'Raw Points',
                      color: const Color(0xFF3182CE),
                      onTap: () async {
                        try {
                          await CsvExportService()
                              .exportRawPointsCSV(session);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('CSV error: $e')));
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Session info strip ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _InfoChip(
                      label: 'Strokes',
                      value: session.strokeCount.toString()),
                  _InfoChip(
                      label: 'Points',
                      value: session.totalPoints.toString()),
                  _InfoChip(
                      label: 'Features',
                      value: session.features.length.toString()),
                ],
              ),
            ),
          ),

          // ── Feature breakdown ─────────────────────────────────────────
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Feature Breakdown',
                    style: GoogleFonts.fraunces(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A18))),
              ),
              FeatureCard(
                title: 'Spatial Features',
                features: spatialFeats,
                accentColor: const Color(0xFF1A3C5E),
              ),
              FeatureCard(
                title: 'Temporal Features',
                features: temporalFeats,
                accentColor: const Color(0xFF1A3C5E),
              ),
              FeatureCard(
                title: 'Dynamic Features',
                features: dynamicFeats,
                accentColor: const Color(0xFF1A3C5E),
              ),
              FeatureCard(
                title: 'Fluency Scores',
                features: fluencyFeats,
                accentColor: scoreColor,
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildImageResults(BuildContext context) {
    final idx = session.irregularityIndex;
    final scoreColor = _scoreColor(idx);
    final spatialFeats = _filter(session.features, _imageSpatialKeys);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      body: CustomScrollView(
        slivers: [
          // ── Hero app bar ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A18),
          leading: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: const Color(0xFF1A1A18),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Score gauge
                      _ScoreGauge(index: idx, color: scoreColor, isImage: true),
                      const SizedBox(height: 12),
                      // Classification badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: scoreColor, width: 1.5),
                        ),
                        child: Text(
                          session.classification,
                          style: GoogleFonts.fraunces(
                            color: scoreColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('dd MMM yyyy • HH:mm')
                            .format(session.timestamp),
                        style: GoogleFonts.inter(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (session.isLowConfidence)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFEB2B2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFC53030), size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        session.confidenceMessage ?? 'Low image quality or insufficient handwriting detected — result may be unreliable.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9B2C2C),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Info banner explaining image limitations ────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFE2E2DE),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF1A3C5E), size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Static photos lack temporal data. Velocity, acceleration, pauses, and tempo are physically unrecoverable and excluded from this analysis.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF5C5C5A),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Export buttons (only PDF and CSV features) ───────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ExportButton(
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'Export PDF',
                      color: const Color(0xFFE53E3E),
                      onTap: () async {
                        try {
                          await PdfReportService().exportPdf(session);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('PDF error: $e')));
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ExportButton(
                      icon: Icons.table_chart_rounded,
                      label: 'Export CSV',
                      color: const Color(0xFF38A169),
                      onTap: () async {
                        try {
                          await CsvExportService()
                              .exportFeaturesCSV(session);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('CSV error: $e')));
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Session info strip ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  const _InfoChip(
                      label: 'Source',
                      value: 'Image Upload'),
                  _InfoChip(
                      label: 'Features',
                      value: session.features.length.toString()),
                ],
              ),
            ),
          ),

          // ── Feature breakdown ─────────────────────────────────────────
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Feature Breakdown',
                    style: GoogleFonts.fraunces(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A18))),
              ),
              FeatureCard(
                title: 'Spatial & Structural Features',
                features: spatialFeats,
                accentColor: const Color(0xFF1A3C5E),
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double idx) {
    if (idx < 0.35) return Colors.green.shade600;
    if (idx < 0.60) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  Map<String, double> _filter(Map<String, double> all, List<String> keys) =>
      {for (final k in keys) if (all.containsKey(k)) k: all[k]!};
}

// ── Score gauge ──────────────────────────────────────────────────────────────

class _ScoreGauge extends StatelessWidget {
  final double index;
  final Color color;
  final bool isImage;

  const _ScoreGauge({
    required this.index,
    required this.color,
    this.isImage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          (index * 100).toStringAsFixed(0),
          style: GoogleFonts.fraunces(
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        Text(
          isImage ? 'Static Handwriting Score' : 'Kinematic Irregularity Index',
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Export button ────────────────────────────────────────────────────────────

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Info chip ────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final String label, value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.fraunces(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A18))),
        Text(label,
            style:
                GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8C8C8A))),
      ],
    );
  }
}

const _spatialKeys = [
  'stroke_length', 'bounding_width', 'bounding_height', 'aspect_ratio',
  'mean_slant', 'mean_curvature', 'straightness', 'writing_density',
  'baseline_deviation', 'center_of_mass_x', 'center_of_mass_y',
];
const _temporalKeys = [
  'total_duration', 'pen_down_duration', 'pen_down_ratio',
  'pause_count', 'mean_pause_duration', 'writing_tempo', 'rhythm_regularity',
];
const _dynamicKeys = [
  'mean_velocity', 'max_velocity', 'velocity_variance',
  'mean_acceleration', 'mean_jerk', 'normalized_jerk',
  'direction_changes', 'tremor_frequency', 'tremor_amplitude',
];
const _fluencyKeys = ['irregularity_index', 'fluency_score', 'consistency_score'];

const _imageSpatialKeys = [
  'average_stroke_width',
  'stroke_width_variance',
  'ink_density',
  'average_slant_angle',
  'slant_angle_variance',
  'line_spacing',
  'line_spacing_variance',
  'word_spacing',
  'word_spacing_variance',
  'baseline_deviation',
];
