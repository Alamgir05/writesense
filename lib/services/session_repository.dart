import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/session.dart';

// Conditionally import dart:io and sqflite only on non-web platforms
import 'session_repository_native.dart'
    if (dart.library.html) 'session_repository_web.dart' as platform_repo;

/// SQLite-backed repository for [Session] objects on native (Android/Linux/iOS).
/// Falls back to in-memory storage on web (sessions persist for the app session only).
class SessionRepository {
  // ── Web: in-memory fallback ───────────────────────────────────────────────
  // Sessions are stored in the singleton provider so they survive navigation,
  // but are lost on page refresh. Sufficient for Chrome testing.
  final List<Session> _webSessions = [];

  Future<void> insertSession(Session session) async {
    if (kIsWeb) {
      _webSessions.removeWhere((s) => s.id == session.id);
      _webSessions.insert(0, session);
      return;
    }
    await platform_repo.insertSession(session);
  }

  Future<List<Session>> getAllSessions() async {
    if (kIsWeb) return List<Session>.from(_webSessions);
    return platform_repo.getAllSessions();
  }

  Future<Session?> getSessionById(String id) async {
    if (kIsWeb) {
      try {
        return _webSessions.firstWhere((s) => s.id == id);
      } catch (_) {
        return null;
      }
    }
    return platform_repo.getSessionById(id);
  }

  Future<void> deleteSession(String id) async {
    if (kIsWeb) {
      _webSessions.removeWhere((s) => s.id == id);
      return;
    }
    return platform_repo.deleteSession(id);
  }
}
