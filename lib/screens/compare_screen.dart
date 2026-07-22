import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';

// ── Feature-group definitions (mirrors results_screen.dart) ──────────────────

const _tabletGroups = <String, List<String>>{
  'Spatial': [
    'stroke_length', 'bounding_width', 'bounding_height', 'aspect_ratio',
    'mean_slant', 'mean_curvature', 'straightness', 'writing_density',
    'baseline_deviation', 'center_of_mass_x', 'center_of_mass_y',
  ],
  'Temporal': [
    'total_duration', 'pen_down_duration', 'pen_down_ratio',
    'pause_count', 'mean_pause_duration', 'writing_tempo', 'rhythm_regularity',
  ],
  'Dynamic': [
    'mean_velocity', 'max_velocity', 'velocity_variance',
    'mean_acceleration', 'mean_jerk', 'normalized_jerk',
    'direction_changes', 'tremor_frequency', 'tremor_amplitude',
  ],
  'Fluency': [
    'irregularity_index', 'fluency_score', 'consistency_score',
  ],
};

const _imageGroups = <String, List<String>>{
  'Spatial & Structural': [
    'average_stroke_width', 'stroke_width_variance', 'ink_density',
    'average_slant_angle', 'slant_angle_variance', 'line_spacing',
    'line_spacing_variance', 'word_spacing', 'word_spacing_variance',
    'baseline_deviation',
  ],
};

// ── Pretty-print feature key ──────────────────────────────────────────────────

String _prettyKey(String key) =>
    key.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');

// ── Delta helper ──────────────────────────────────────────────────────────────

/// Returns formatted delta string e.g. "−17.8%" or "N/A".
String _deltaLabel(double baseline, double other) {
  if (baseline == 0) return 'N/A'; // guard division by zero
  final pct = ((other - baseline) / baseline) * 100;
  final sign = pct >= 0 ? '+' : '−';
  return '$sign${pct.abs().toStringAsFixed(1)}%';
}

Color _deltaColor(double baseline, double other) {
  if (baseline == 0) return const Color(0xFF8C8C8A);
  final pct = ((other - baseline) / baseline) * 100;
  if (pct.abs() < 1) return const Color(0xFF8C8C8A); // negligible
  return pct < 0 ? Colors.green.shade600 : Colors.red.shade600;
}

// ── CompareScreen ─────────────────────────────────────────────────────────────

class CompareScreen extends StatelessWidget {
  final List<Session> sessions;

  const CompareScreen({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    assert(sessions.length >= 2, 'CompareScreen requires at least 2 sessions');

    // Mixed-type guard: all must have same source
    final allTablet = sessions.every((s) => s.isTablet);
    final allImage = sessions.every((s) => s.isImage);
    final isMixed = !allTablet && !allImage;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      body: SafeArea(
        child: Column(
          children: [
            _Header(sessionCount: sessions.length),
            Expanded(
              child: isMixed
                  ? _MixedTypeBlock()
                  : _ComparisonBody(sessions: sessions, groups: allTablet ? _tabletGroups : _imageGroups),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int sessionCount;
  const _Header({required this.sessionCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3C5E).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF1A3C5E), size: 16),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session Comparison',
                style: GoogleFonts.fraunces(
                  color: const Color(0xFF1A1A18),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$sessionCount sessions selected',
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF8C8C8A)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Mixed-type blocking message ───────────────────────────────────────────────

class _MixedTypeBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E2DE)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.compare_arrows_rounded,
                    color: Colors.orange.shade700, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Cannot Compare Mixed Types',
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A18),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your selection contains both tablet and image sessions. '
                'The Kinematic Irregularity Index (tablet) and the Static '
                'Handwriting Score (image) are computed on different scales '
                'and cannot be directly compared — doing so would produce '
                'misleading numbers.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF5C5C5A),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Please select sessions of the same type (all tablet or all image).',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A3C5E),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Comparison body ───────────────────────────────────────────────────────────

class _ComparisonBody extends StatelessWidget {
  final List<Session> sessions;
  final Map<String, List<String>> groups;

  const _ComparisonBody({required this.sessions, required this.groups});

  @override
  Widget build(BuildContext context) {
    final baseline = sessions.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Session header cards ───────────────────────────────────────
          _SessionHeaderRow(sessions: sessions),
          const SizedBox(height: 16),

          // ── Feature group tables ───────────────────────────────────────
          ...groups.entries.map((entry) {
            final presentKeys = entry.value
                .where((k) => sessions.any((s) => s.features.containsKey(k)))
                .toList();
            if (presentKeys.isEmpty) return const SizedBox.shrink();
            return _GroupTable(
              groupName: entry.key,
              featureKeys: presentKeys,
              sessions: sessions,
              baseline: baseline,
            );
          }),
        ],
      ),
    );
  }
}

// ── Session header row ────────────────────────────────────────────────────────

class _SessionHeaderRow extends StatelessWidget {
  final List<Session> sessions;
  const _SessionHeaderRow({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yy\nHH:mm');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Spacer matching the feature-name column width
          const SizedBox(width: 130),
          ...sessions.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            final idx = s.irregularityIndex;
            final color = _scoreColor(idx);
            final isBaseline = i == 0;
            return Container(
              width: 120,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isBaseline
                    ? const Color(0xFF1A3C5E).withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isBaseline
                      ? const Color(0xFF1A3C5E).withValues(alpha: 0.3)
                      : const Color(0xFFE2E2DE),
                ),
              ),
              child: Column(
                children: [
                  if (isBaseline)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3C5E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Baseline',
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  Text(
                    '${(idx * 100).round()}%',
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.classification,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFmt.format(s.timestamp),
                    style: GoogleFonts.inter(
                        fontSize: 9, color: const Color(0xFF8C8C8A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        s.isImage ? Icons.image_outlined : Icons.gesture_rounded,
                        size: 11,
                        color: const Color(0xFF8C8C8A),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        s.isImage ? 'Image' : 'Tablet',
                        style: GoogleFonts.inter(
                            fontSize: 9, color: const Color(0xFF8C8C8A)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _scoreColor(double idx) {
    if (idx < 0.35) return Colors.green.shade600;
    if (idx < 0.60) return Colors.orange.shade600;
    return Colors.red.shade600;
  }
}

// ── Feature group table ───────────────────────────────────────────────────────

class _GroupTable extends StatefulWidget {
  final String groupName;
  final List<String> featureKeys;
  final List<Session> sessions;
  final Session baseline;

  const _GroupTable({
    required this.groupName,
    required this.featureKeys,
    required this.sessions,
    required this.baseline,
  });

  @override
  State<_GroupTable> createState() => _GroupTableState();
}

class _GroupTableState extends State<_GroupTable> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E2DE)),
      ),
      child: Column(
        children: [
          // Group header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3C5E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.groupName,
                      style: GoogleFonts.fraunces(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A18),
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF8C8C8A),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E2DE)),
            // Column headers: feature name + one column per session
            _ColumnHeaderRow(sessions: widget.sessions),
            const Divider(height: 1, color: Color(0xFFE2E2DE)),
            // Feature rows
            ...widget.featureKeys.asMap().entries.map((e) {
              final isLast = e.key == widget.featureKeys.length - 1;
              return _FeatureRow(
                featureKey: e.value,
                sessions: widget.sessions,
                baseline: widget.baseline,
                isLast: isLast,
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ── Column header row ─────────────────────────────────────────────────────────

class _ColumnHeaderRow extends StatelessWidget {
  final List<Session> sessions;
  const _ColumnHeaderRow({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d/M HH:mm');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Feature name column header
          SizedBox(
            width: 130,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('Feature',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8C8C8A))),
            ),
          ),
          // One column per session
          ...sessions.asMap().entries.map((e) {
            final isBaseline = e.key == 0;
            return SizedBox(
              width: 120,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  isBaseline
                      ? 'Baseline\n${dateFmt.format(e.value.timestamp)}'
                      : dateFmt.format(e.value.timestamp),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isBaseline
                        ? const Color(0xFF1A3C5E)
                        : const Color(0xFF5C5C5A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Feature row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final String featureKey;
  final List<Session> sessions;
  final Session baseline;
  final bool isLast;

  const _FeatureRow({
    required this.featureKey,
    required this.sessions,
    required this.baseline,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final baselineVal = baseline.features[featureKey];

    return Container(
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFEEEEEB), width: 1))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Feature name
            SizedBox(
              width: 130,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  _prettyKey(featureKey),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A1A18),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // One cell per session
            ...sessions.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              final val = s.features[featureKey];
              final isBaseline = i == 0;

              if (val == null) {
                return SizedBox(
                  width: 120,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    child: Text('—',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: const Color(0xFF8C8C8A)),
                        textAlign: TextAlign.center),
                  ),
                );
              }

              if (isBaseline) {
                // Baseline: just show the raw value
                return SizedBox(
                  width: 120,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    child: Text(
                      _formatVal(val),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A18),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              // Non-baseline: show value + delta badge
              final delta = baselineVal == null
                  ? null
                  : _deltaLabel(baselineVal, val);
              final deltaCol = baselineVal == null
                  ? const Color(0xFF8C8C8A)
                  : _deltaColor(baselineVal, val);

              return SizedBox(
                width: 120,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatVal(val),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A18),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (delta != null) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: deltaCol.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            delta,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: deltaCol,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatVal(double v) {
    if (v == v.truncate() && v.abs() < 1e6) {
      // Whole number
      return v.toStringAsFixed(0);
    }
    if (v.abs() >= 1000) return v.toStringAsFixed(1);
    if (v.abs() >= 1) return v.toStringAsFixed(3);
    return v.toStringAsFixed(4);
  }
}
