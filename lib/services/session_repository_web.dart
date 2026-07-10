// Web stub — these functions are never called on web because SessionRepository
// always uses the in-memory _webSessions list when kIsWeb is true.
// This file exists only to satisfy the conditional import.
import '../models/session.dart';

Future<void> insertSession(Session session) async {}
Future<List<Session>> getAllSessions() async => [];
Future<Session?> getSessionById(String id) async => null;
Future<void> deleteSession(String id) async {}
