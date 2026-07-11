import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/session.dart';

/// Firestore CRUD for Session documents.
/// All reads/writes are scoped to users/{uid}/sessions — enforced by rules.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('users').doc(_uid).collection('sessions');

  /// Save or overwrite a session document
  Future<void> saveSession(Session session) async {
    await _sessions.doc(session.id).set(session.toFirestoreMap());
  }

  /// Load all sessions for the current user, newest first
  Future<List<Session>> getAllSessions() async {
    final snap = await _sessions
        .orderBy('timestamp', descending: true)
        .get();
    return snap.docs.map((d) => Session.fromFirestoreDoc(d)).toList();
  }

  /// Real-time stream of sessions (used by history screen)
  Stream<List<Session>> sessionsStream() {
    return _sessions
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Session.fromFirestoreDoc(d)).toList());
  }

  /// Delete a single session
  Future<void> deleteSession(String id) async {
    await _sessions.doc(id).delete();
  }
}
