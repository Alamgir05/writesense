import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';

/// A list tile for displaying a [Session] summary in history view.
///
/// When [isSelected] and [onToggleSelect] are non-null the tile enters
/// "selection mode": a checkbox overlay appears on the score badge and the
/// swipe-to-delete gesture is disabled. The existing [onTap] callback is
/// unchanged — callers in selection mode should wire it to [onToggleSelect].
class SessionTile extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Selection-mode params — both must be non-null to activate selection mode.
  final bool? isSelected;
  final VoidCallback? onToggleSelect;

  const SessionTile({
    super.key,
    required this.session,
    required this.onTap,
    required this.onDelete,
    this.isSelected,
    this.onToggleSelect,
  });

  bool get _selectionMode => isSelected != null && onToggleSelect != null;

  @override
  Widget build(BuildContext context) {
    final idx = session.irregularityIndex;
    final color = _scoreColor(idx);
    final dateFmt = DateFormat('MMM d, yyyy • HH:mm');

    // Core tile content — same whether or not in selection mode
    final tileContent = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _selectionMode && (isSelected ?? false)
            ? const Color(0xFF1A3C5E).withValues(alpha: 0.06)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _selectionMode && (isSelected ?? false)
              ? const Color(0xFF1A3C5E).withValues(alpha: 0.4)
              : const Color(0xFFE2E2DE),
          width: _selectionMode && (isSelected ?? false) ? 1.5 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          onTap: _selectionMode ? onToggleSelect : onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _selectionMode
              ? _CheckableBadge(
                  score: idx, color: color, selected: isSelected ?? false)
              : _ScoreBadge(score: idx, color: color),
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
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF5C5C5A))),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                session.isImage
                    ? 'Static Photo'
                    : '${session.strokeCount} strokes',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A1A18)),
              ),
              const SizedBox(height: 2),
              Text(
                session.isImage
                    ? '10 features'
                    : '${session.totalPoints} pts',
                style: GoogleFonts.inter(
                    fontSize: 10, color: const Color(0xFF8C8C8A)),
              ),
            ],
          ),
        ),
      ),
    );

    // In selection mode: disable swipe-to-delete
    if (_selectionMode) return tileContent;

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
      child: tileContent,
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

/// Score badge with a checkbox overlay — used in selection mode.
class _CheckableBadge extends StatelessWidget {
  final double score;
  final Color color;
  final bool selected;

  const _CheckableBadge({
    required this.score,
    required this.color,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        children: [
          // Underlying score badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: selected
                  ? const Color(0xFF1A3C5E).withValues(alpha: 0.12)
                  : color.withValues(alpha: 0.12),
              border: Border.all(
                color: selected ? const Color(0xFF1A3C5E) : color,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                '${(score * 100).round()}%',
                style: GoogleFonts.fraunces(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: selected ? const Color(0xFF1A3C5E) : color,
                ),
              ),
            ),
          ),
          // Checkbox overlay — bottom right corner
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF1A3C5E) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF1A3C5E)
                      : const Color(0xFF8C8C8A),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
