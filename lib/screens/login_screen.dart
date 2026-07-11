import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(bool isSignUp) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final auth = ref.read(authServiceProvider);
      if (isSignUp) {
        await auth.signUp(_emailCtrl.text.trim(), _passwordCtrl.text);
      } else {
        await auth.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
      }
    } on Exception catch (e) {
      final code = e.toString().split('/').last.replaceAll(']', '').trim();
      setState(() => _error = AuthService.friendlyError(code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    const Text('✍', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 12),
                    Text('WriteSense',
                        style: GoogleFonts.inter(
                            fontSize: 32, fontWeight: FontWeight.w800,
                            foreground: Paint()..shader = const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF38EF7D)],
                            ).createShader(const Rect.fromLTWH(0, 0, 200, 40)))),
                    const SizedBox(height: 6),
                    Text('Handwriting Irregularity Detection',
                        style: GoogleFonts.inter(
                            color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 40),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF24243E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Sign In', style: GoogleFonts.inter(
                                fontSize: 22, fontWeight: FontWeight.bold,
                                color: Colors.white)),
                            const SizedBox(height: 20),

                            // Error
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                                ),
                                child: Text(_error!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Email
                            _Field(
                              controller: _emailCtrl,
                              label: 'Email',
                              hint: 'you@example.com',
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) =>
                                  (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                            ),
                            const SizedBox(height: 14),

                            // Password
                            _Field(
                              controller: _passwordCtrl,
                              label: 'Password',
                              hint: '••••••••',
                              obscureText: _obscure,
                              validator: (v) =>
                                  (v == null || v.length < 6) ? 'Min 6 characters' : null,
                              suffix: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.white38, size: 20),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Sign In button
                            _Button(
                              label: _loading ? 'Signing in…' : 'Sign In',
                              onPressed: _loading ? null : () => _submit(false),
                              loading: _loading,
                            ),
                            const SizedBox(height: 10),

                            // Sign Up button
                            OutlinedButton(
                              onPressed: _loading ? null : () => _submit(true),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF6C63FF)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('Create Account',
                                  style: GoogleFonts.inter(
                                      color: const Color(0xFF6C63FF),
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffix;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        labelStyle: const TextStyle(color: Colors.white54),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF1A1740),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const _Button({required this.label, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: const Color(0xFF6C63FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(
              height: 18, width: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : Text(label,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
    );
  }
}
