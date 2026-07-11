import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../services/firestore_service.dart';

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

/// Real-time stream of sessions from Firestore (replaces SQLite history).
final historyProvider = StreamProvider<List<Session>>((ref) {
  return ref.watch(firestoreServiceProvider).sessionsStream();
});

/// Notifier for delete operations on top of the stream
extension HistoryDelete on WidgetRef {
  Future<void> deleteSession(String id) async {
    await read(firestoreServiceProvider).deleteSession(id);
  }
}
