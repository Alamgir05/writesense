import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../providers/history_provider.dart';
import '../widgets/session_tile.dart';
import 'results_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF302B63)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Session History',
            style: GoogleFonts.inter(
                color: const Color(0xFF302B63),
                fontWeight: FontWeight.bold)),
      ),
      body: historyAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
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
                    return SessionTile(
                      session: session,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ResultsScreen(session: session)),
                      ),
                      onDelete: () => ref
                          .read(firestoreServiceProvider)
                          .deleteSession(session.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Irregularity Trend',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: const Color(0xFF302B63))),
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
                    color: const Color(0xFF6C63FF),
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
                          const Color(0xFF6C63FF).withValues(alpha: 0.2),
                          const Color(0xFF6C63FF).withValues(alpha: 0.0),
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
          Icon(Icons.history_rounded, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No sessions yet',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('Complete a handwriting test to see history here',
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}
