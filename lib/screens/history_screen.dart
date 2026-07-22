import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../providers/history_provider.dart';
import '../widgets/session_tile.dart';
import '../widgets/styled_progress_indicator.dart';
import 'results_screen.dart';
import 'compare_screen.dart';

Route _createFadeSlideRoute(Widget screen) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => screen,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.05, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;

      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      final offsetAnimation = animation.drive(tween);
      final fadeAnimation = animation.drive(Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve)));

      return SlideTransition(
        position: offsetAnimation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: child,
        ),
      );
    },
  );
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSession(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _openComparison(List<Session> allSessions) {
    final selected = allSessions.where((s) => _selectedIds.contains(s.id)).toList();
    if (selected.length < 2) return;

    // Mixed-type check in history screen — show a snackbar before navigating
    // (CompareScreen also blocks, but this gives earlier feedback)
    final allTablet = selected.every((s) => s.isTablet);
    final allImage = selected.every((s) => s.isImage);
    if (!allTablet && !allImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot compare tablet and image sessions — they use different '
            'scales (Kinematic Irregularity Index vs Static Handwriting Score).',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: const Color(0xFF1A3C5E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 4),
        ),
      );
      // Still navigate to show the block screen for full context
    }

    Navigator.push(context, _createFadeSlideRoute(CompareScreen(sessions: selected)));
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom AppBar-less Header ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _selectionMode
                        ? _toggleSelectionMode  // exit selection mode
                        : () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3C5E).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectionMode ? Icons.close : Icons.arrow_back_ios_new_rounded,
                        color: const Color(0xFF1A3C5E),
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectionMode ? 'Select Sessions' : 'Session History',
                          style: GoogleFonts.fraunces(
                            color: const Color(0xFF1A1A18),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectionMode)
                          Text(
                            _selectedIds.isEmpty
                                ? 'Tap sessions to select'
                                : '${_selectedIds.length} selected',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: const Color(0xFF1A3C5E)),
                          ),
                      ],
                    ),
                  ),
                  // ── Compare toggle icon ──────────────────────────────
                  historyAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (sessions) => sessions.length >= 2
                        ? Tooltip(
                            message: _selectionMode
                                ? 'Exit selection mode'
                                : 'Compare sessions',
                            child: GestureDetector(
                              onTap: _toggleSelectionMode,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _selectionMode
                                      ? const Color(0xFF1A3C5E)
                                      : const Color(0xFF1A3C5E)
                                            .withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.compare_arrows_rounded,
                                  color: _selectionMode
                                      ? Colors.white
                                      : const Color(0xFF1A3C5E),
                                  size: 18,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            Expanded(
              child: historyAsync.when(
                loading: () => const Center(child: StyledProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return _EmptyState();
                  }
                  return Column(
                    children: [
                      // ── Trend chart (hidden in selection mode) ───────────
                      if (sessions.length >= 2 && !_selectionMode)
                        _TrendChart(sessions: sessions),
                      // ── Selection mode hint banner ────────────────────────
                      if (_selectionMode)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A3C5E).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF1A3C5E).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: Color(0xFF1A3C5E), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Select 2 or more sessions of the same type (all tablet or all image) to compare.',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF1A3C5E)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // ── Session list ─────────────────────────────────────
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: sessions.length,
                          itemBuilder: (context, i) {
                            final session = sessions[i];
                            final isSelected = _selectedIds.contains(session.id);
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(
                                  milliseconds:
                                      300 + (i * 40).clamp(0, 300)),
                              curve: Curves.easeOutCubic,
                              builder: (context, val, child) {
                                return Transform.translate(
                                  offset: Offset(0, 16 * (1.0 - val)),
                                  child: Opacity(opacity: val, child: child),
                                );
                              },
                              child: SessionTile(
                                session: session,
                                onTap: () => Navigator.push(
                                  context,
                                  _createFadeSlideRoute(
                                      ResultsScreen(session: session)),
                                ),
                                onDelete: () => ref
                                    .read(firestoreServiceProvider)
                                    .deleteSession(session.id),
                                // Selection mode props (null = normal mode)
                                isSelected: _selectionMode ? isSelected : null,
                                onToggleSelect: _selectionMode
                                    ? () => _toggleSession(session.id)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // ── Compare FAB — only shown when 2+ sessions selected ───────────────
      floatingActionButton: _selectionMode && _selectedIds.length >= 2
          ? historyAsync.whenOrNull(
              data: (sessions) => FloatingActionButton.extended(
                onPressed: () => _openComparison(sessions),
                backgroundColor: const Color(0xFF1A3C5E),
                icon: const Icon(Icons.compare_arrows_rounded,
                    color: Colors.white),
                label: Text(
                  'Compare ${_selectedIds.length}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ── Trend chart ───────────────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  final List<Session> sessions;

  const _TrendChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    // Reverse so oldest is leftmost
    final ordered = sessions.reversed.toList();

    // Group/thin out sessions from the same rapid manual testing burst (within 5 minutes)
    final thinned = <Session>[];
    for (final s in ordered) {
      if (thinned.isEmpty) {
        thinned.add(s);
      } else {
        final last = thinned.last;
        final diff = s.timestamp.difference(last.timestamp).abs();
        if (diff.inMinutes < 5) {
          // Replace with the latest session in the 5-minute burst
          thinned[thinned.length - 1] = s;
        } else {
          thinned.add(s);
        }
      }
    }

    final spots = thinned.asMap().entries.map((e) {
      return FlSpot(
          e.key.toDouble(), e.value.irregularityIndex);
    }).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E2DE), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Irregularity Trend',
              style: GoogleFonts.fraunces(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: const Color(0xFF1A1A18))),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 1,
                gridData: FlGridData(
                  drawHorizontalLine: true,
                  horizontalInterval: 0.25,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 0.5,
                      getTitlesWidget: (v, _) => Text(
                        '${(v * 100).round()}%',
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= thinned.length) {
                          return const SizedBox.shrink();
                        }
                        // Show at most 5 evenly-spaced labels
                        final total = thinned.length;
                        final showLabel = total <= 5 ||
                            i == 0 ||
                            i == total - 1 ||
                            (total > 2 && i == (total / 2).floor()) ||
                            (total > 4 && (i == (total / 4).floor() || i == (3 * total / 4).floor()));
                        if (!showLabel) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            DateFormat('d MMM').format(thinned[i].timestamp),
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8C8C8A),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF1A3C5E),
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, pct, bar, idx) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: _dotColor(spot.y),
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF1A3C5E).withValues(alpha: 0.2),
                          const Color(0xFF1A3C5E).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                // Reference lines at thresholds
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 0.35,
                      color: Colors.orange.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                    HorizontalLine(
                      y: 0.60,
                      color: Colors.red.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _dotColor(double y) {
    if (y < 0.35) return Colors.green.shade500;
    if (y < 0.60) return Colors.orange.shade500;
    return Colors.red.shade500;
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_outlined, size: 64, color: Color(0xFF8C8C8A)),
          const SizedBox(height: 16),
          Text('No sessions yet',
              style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A18))),
          const SizedBox(height: 8),
          Text('Complete a handwriting test to see history here',
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFF8C8C8A))),
        ],
      ),
    );
  }
}
