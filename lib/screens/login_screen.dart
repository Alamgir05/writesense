import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../widgets/pressable_scale.dart';

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
      backgroundColor: const Color(0xFFFAFAF8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  const Icon(Icons.gesture_rounded, size: 56, color: Color(0xFF1A3C5E)),
                  const SizedBox(height: 12),
                  Text('WriteSense',
                      style: GoogleFonts.fraunces(
                          fontSize: 36, fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A18))),
                  const SizedBox(height: 6),
                  Text('Handwriting Irregularity Detection',
                      style: GoogleFonts.inter(
                          color: const Color(0xFF8C8C8A), fontSize: 14)),
                    const SizedBox(height: 40),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFE2E2DE), width: 1),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Sign In', style: GoogleFonts.fraunces(
                                fontSize: 22, fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1A18))),
                            const SizedBox(height: 20),

                            // Error
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                                ),
                                child: Text(_error!,
                                    style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
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
                                    color: const Color(0xFF8C8C8A), size: 20),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Sign In button
                            PressableScale(
                              onTap: _loading ? null : () => _submit(false),
                              child: _Button(
                                label: _loading ? 'Signing in…' : 'Sign In',
                                onPressed: _loading ? null : () => _submit(false),
                                loading: _loading,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Sign Up button
                            PressableScale(
                              onTap: _loading ? null : () => _submit(true),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF1A3C5E)),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Create Account',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF1A3C5E),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
      style: const TextStyle(color: Color(0xFF1A1A18)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF8C8C8A)),
        labelStyle: const TextStyle(color: Color(0xFF5C5C5A)),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFFAFAF8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E2DE), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E2DE), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1A3C5E), width: 1.5),
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
        backgroundColor: const Color(0xFF1A3C5E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(
              height: 18, width: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : Text(label,
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
    );
  }
}
