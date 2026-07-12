import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';

/// A list tile for displaying a [Session] summary in history view.
class SessionTile extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SessionTile({
    super.key,
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final idx = session.irregularityIndex;
    final color = _scoreColor(idx);
    final dateFmt = DateFormat('MMM d, yyyy • HH:mm');

    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFE2E2DE),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ListTile(
            onTap: onTap,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: _ScoreBadge(score: idx, color: color),
            title: Text(
              session.classification,
              style: GoogleFonts.fraunces(
                  fontWeight: FontWeight.bold, color: color, fontSize: 16),
            ),
            subtitle: Row(
              children: [
                Icon(
                  session.isImage ? Icons.image_outlined : Icons.gesture_rounded,
                  size: 14,
                  color: const Color(0xFF8C8C8A),
                ),
                const SizedBox(width: 6),
                Text(dateFmt.format(session.timestamp),
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF5C5C5A))),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  session.isImage ? 'Static Photo' : '${session.strokeCount} strokes',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF1A1A18)),
                ),
                const SizedBox(height: 2),
                Text(
                  session.isImage ? '10 features' : '${session.totalPoints} pts',
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF8C8C8A)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _scoreColor(double idx) {
    if (idx < 0.35) return Colors.green.shade600;
    if (idx < 0.60) return Colors.orange.shade600;
    return Colors.red.shade600;
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;
  final Color color;

  const _ScoreBadge({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 1),
      ),
      child: Center(
        child: Text(
          '${(score * 100).round()}%',
          style: GoogleFonts.fraunces(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
