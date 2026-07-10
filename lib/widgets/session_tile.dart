import 'package:flutter/material.dart';
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
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        color: Theme.of(context).colorScheme.surface,
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _ScoreBadge(score: idx, color: color),
          title: Text(
            session.classification,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 15),
          ),
          subtitle: Text(dateFmt.format(session.timestamp),
              style: const TextStyle(fontSize: 12)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${session.strokeCount} strokes',
                  style: const TextStyle(fontSize: 11)),
              const SizedBox(height: 2),
              Text('${session.totalPoints} pts',
                  style: const TextStyle(fontSize: 11)),
            ],
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
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          '${(score * 100).round()}%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
