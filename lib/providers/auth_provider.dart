import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Streams the current Firebase user (null when signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Convenience: returns the current user synchronously (throws if null).
final currentUserProvider = Provider<User>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) throw StateError('Not authenticated');
  return user;
});
