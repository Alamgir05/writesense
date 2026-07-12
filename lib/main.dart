import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: WriteSenseApp()));
}

class WriteSenseApp extends ConsumerWidget {
  const WriteSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'WriteSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFAFAF8),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1A3C5E),
          onPrimary: Colors.white,
          secondary: Color(0xFF1A3C5E),
          surface: Colors.white,
          onSurface: Color(0xFF1C1C1E),
          outline: Color(0xFFE2E2DE),
        ),
        textTheme: GoogleFonts.interTextTheme(
            ThemeData(brightness: Brightness.light).textTheme),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE2E2DE), width: 1),
          ),
          color: Colors.white,
        ),
      ),
      // Auth gate: show LoginScreen until Firebase confirms the user is signed in
      home: ref.watch(authStateProvider).when(
        loading: () => const _SplashScreen(),
        error:   (_, e) => const LoginScreen(),
        data:    (user) => user != null ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }
}

/// Shown while Firebase checks the persisted auth token on startup
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFAFAF8),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✍', style: TextStyle(fontSize: 60)),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Color(0xFF1A3C5E)),
          ],
        ),
      ),
    );
  }
}
