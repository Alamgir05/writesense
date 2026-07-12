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

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  Text(
                    'Session History',
                    style: GoogleFonts.fraunces(
                      color: const Color(0xFF1A1A18),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
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
                      // ── Trend chart ─────────────────────────────────────────
                      if (sessions.length >= 2)
                        _TrendChart(sessions: sessions),
                      // ── Session list ─────────────────────────────────────────
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          itemCount: sessions.length,
                          itemBuilder: (context, i) {
                            final session = sessions[i];
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 300 + (i * 40).clamp(0, 300)),
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
                                  _createFadeSlideRoute(ResultsScreen(session: session)),
                                ),
                                onDelete: () => ref
                                    .read(firestoreServiceProvider)
                                    .deleteSession(session.id),
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

    final spots = ordered.asMap().entries.map((e) {
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
                        if (i < 0 || i >= ordered.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          DateFormat('d/M').format(ordered[i].timestamp),
                          style: const TextStyle(fontSize: 8),
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
