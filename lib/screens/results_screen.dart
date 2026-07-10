import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../services/pdf_report_service.dart';
import '../services/csv_export_service.dart';
import '../widgets/feature_card.dart';

class ResultsScreen extends StatelessWidget {
  final Session session;

  const ResultsScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final idx = session.irregularityIndex;
    final scoreColor = _scoreColor(idx);
    final spatialFeats = _filter(session.features, _spatialKeys);
    final temporalFeats = _filter(session.features, _temporalKeys);
    final dynamicFeats = _filter(session.features, _dynamicKeys);
    final fluencyFeats = _filter(session.features, _fluencyKeys);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FF),
      body: CustomScrollView(
        slivers: [
          // ── Hero app bar ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFF302B63),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F0C29), Color(0xFF302B63)],
                  ),
                ),
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
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: scoreColor, width: 1.5),
                        ),
                        child: Text(
                          session.classification,
                          style: GoogleFonts.inter(
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
                            color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
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
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF302B63))),
              ),
              FeatureCard(
                title: 'Spatial Features',
                features: spatialFeats,
                accentColor: const Color(0xFF6C63FF),
              ),
              FeatureCard(
                title: 'Temporal Features',
                features: temporalFeats,
                accentColor: const Color(0xFF11998E),
              ),
              FeatureCard(
                title: 'Dynamic Features',
                features: dynamicFeats,
                accentColor: const Color(0xFFED8936),
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

  const _ScoreGauge({required this.index, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: CircularProgressIndicator(
            value: index,
            strokeWidth: 10,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        Column(
          children: [
            Text(
              '${(index * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text('index',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
          ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
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
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF302B63))),
        Text(label,
            style:
                GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
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
