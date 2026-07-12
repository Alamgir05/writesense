import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/session_provider.dart';
import '../widgets/handwriting_canvas.dart';
import '../widgets/pressable_scale.dart';
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

class DrawScreen extends ConsumerWidget {
  const DrawScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawState = ref.watch(drawingProvider);
    final notifier  = ref.read(drawingProvider.notifier);
    final firestore = ref.read(firestoreProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // ── Custom AppBar-less Header ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        notifier.clear();
                        Navigator.pop(context);
                      },
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
                      'Write a Sample',
                      style: GoogleFonts.fraunces(
                        color: const Color(0xFF1A1A18),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (!drawState.isEmpty)
                      PressableScale(
                        onTap: () => notifier.clear(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A3C5E).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF1A3C5E)),
                              const SizedBox(width: 4),
                              Text(
                                'Clear',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF1A3C5E),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Instruction chip ─────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3C5E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Color(0xFF1A3C5E)),
                    const SizedBox(width: 6),
                    Text(
                      'Write naturally — sentences, words, or letters',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: const Color(0xFF1A3C5E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Canvas ───────────────────────────────────────────────────
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E2DE), width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: const HandwritingCanvas(),
                  ),
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
                child: PressableScale(
                  onTap: drawState.isEmpty
                      ? null
                      : () async {
                          _showLoadingDialog(context);
                          try {
                            final session =
                                await notifier.analyzeAndSave(firestore);
                            notifier.clear();
                            if (context.mounted) {
                              Navigator.pop(context); // dismiss loading
                              Navigator.pushReplacement(
                                context,
                                _createFadeSlideRoute(ResultsScreen(session: session)),
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
                  child: Container(
                    decoration: BoxDecoration(
                      color: drawState.isEmpty ? const Color(0xFFE2E2DE) : const Color(0xFF1A3C5E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics_outlined, color: drawState.isEmpty ? const Color(0xFF8C8C8A) : Colors.white),
                        const SizedBox(width: 8),
                        Text('Analyze Handwriting',
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: drawState.isEmpty ? const Color(0xFF8C8C8A) : Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE2E2DE), width: 1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StyledProgressIndicator(),
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
            style: GoogleFonts.fraunces(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1A18))),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, color: const Color(0xFF8C8C8A))),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: const Color(0xFFE2E2DE));
  }
}
