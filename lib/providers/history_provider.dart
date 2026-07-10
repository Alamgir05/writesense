import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../services/session_repository.dart';
import 'session_provider.dart';

// ── History state ─────────────────────────────────────────────────────────

class HistoryNotifier extends StateNotifier<AsyncValue<List<Session>>> {
  final SessionRepository _repo;

  HistoryNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final sessions = await _repo.getAllSessions();
      state = AsyncValue.data(sessions);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> delete(String id) async {
    await _repo.deleteSession(id);
    await load();
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, AsyncValue<List<Session>>>(
  (ref) => HistoryNotifier(ref.read(sessionRepositoryProvider)),
);
