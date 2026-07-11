import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around FirebaseAuth for easy testing and Riverpod injection.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream of auth state changes (null = signed out)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signUp(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  /// Human-friendly error messages for Firebase Auth error codes
  static String friendlyError(String code) {
    const map = {
      'invalid-email':        'Invalid email address.',
      'user-not-found':       'No account found with this email.',
      'wrong-password':       'Incorrect password.',
      'email-already-in-use': 'An account already exists with this email.',
      'weak-password':        'Password must be at least 6 characters.',
      'too-many-requests':    'Too many attempts. Try again later.',
      'invalid-credential':   'Invalid email or password.',
      'network-request-failed': 'Network error. Check your connection.',
    };
    return map[code] ?? 'Error: $code';
  }
}
