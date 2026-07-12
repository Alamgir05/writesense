import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'draw_screen.dart';
import 'history_screen.dart';
import 'upload_screen.dart';
import '../widgets/pressable_scale.dart';

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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            _LogoHero(),
            const SizedBox(height: 40),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Primary Hero Card (New Test)
                    PressableScale(
                      onTap: () => Navigator.push(
                        context,
                        _createFadeSlideRoute(const DrawScreen()),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A3C5E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'New Test',
                                    style: GoogleFonts.fraunces(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start real-time handwriting capture and kinematic analysis',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Row for secondary actions
                    Row(
                      children: [
                        Expanded(
                          child: _SecondaryCard(
                            title: 'Upload Photo',
                            subtitle: 'Analyze handwriting image',
                            icon: Icons.file_upload_outlined,
                            onTap: () => Navigator.push(
                              context,
                              _createFadeSlideRoute(const UploadScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SecondaryCard(
                            title: 'History',
                            subtitle: 'Past test records',
                            icon: Icons.history_rounded,
                            onTap: () => Navigator.push(
                              context,
                              _createFadeSlideRoute(const HistoryScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    
                    // Tagline
                    Text(
                      'Powered by spatial & kinematic diagnostics',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8C8C8A),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.gesture_rounded,
          color: Color(0xFF1A3C5E),
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          'WriteSense',
          style: GoogleFonts.fraunces(
            color: const Color(0xFF1A1A18),
            fontSize: 36,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Handwriting Irregularity Detection',
          style: GoogleFonts.inter(
            color: const Color(0xFF5C5C5A),
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _SecondaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SecondaryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E2DE), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              icon,
              color: const Color(0xFF1A3C5E),
              size: 24,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.fraunces(
                    color: const Color(0xFF1A1A18),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8C8C8A),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
