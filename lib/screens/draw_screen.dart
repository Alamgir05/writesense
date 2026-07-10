import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/session_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/handwriting_canvas.dart';
import 'results_screen.dart';

class DrawScreen extends ConsumerWidget {
  const DrawScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawState = ref.watch(drawingProvider);
    final notifier = ref.read(drawingProvider.notifier);
    final repo = ref.read(sessionRepositoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF302B63)),
          onPressed: () {
            notifier.clear();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Write a Sample',
          style: GoogleFonts.inter(
              color: const Color(0xFF302B63), fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!drawState.isEmpty)
            TextButton.icon(
              onPressed: () {
                notifier.clear();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6C63FF),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            // ── Instruction chip ─────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: Color(0xFF6C63FF)),
                  const SizedBox(width: 6),
                  Text(
                    'Write naturally — sentences, words, or letters',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: const Color(0xFF6C63FF)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Canvas ───────────────────────────────────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: const HandwritingCanvas(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Stats row ────────────────────────────────────────────────
            _StatsRow(
              strokes: drawState.completedStrokes.length,
              points: drawState.completedStrokes
                  .fold(0, (s, st) => s + st.points.length),
            ),
            const SizedBox(height: 16),

            // ── Analyze button ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: drawState.isEmpty
                    ? null
                    : () async {
                        _showLoadingDialog(context);
                        try {
                          final session =
                              await notifier.analyzeAndSave(repo);
                          // Refresh history
                          ref.read(historyProvider.notifier).load();
                          notifier.clear();
                          if (context.mounted) {
                            Navigator.pop(context); // dismiss loading
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ResultsScreen(session: session),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.analytics_rounded),
                label: Text('Analyze Handwriting',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF6C63FF)),
            const SizedBox(height: 16),
            Text('Extracting features…',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int strokes;
  final int points;

  const _StatsRow({required this.strokes, required this.points});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Stat(label: 'Strokes', value: strokes.toString()),
        _Divider(),
        _Stat(label: 'Points', value: points.toString()),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF302B63))),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: Colors.grey.shade300);
  }
}
