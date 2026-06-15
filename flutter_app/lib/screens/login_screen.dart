import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;
  final bool busy;
  final String log;
  final VoidCallback onLogin;

  const LoginScreen({
    super.key, required this.userCtrl, required this.passCtrl,
    required this.busy, required this.log, required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final c = SwaapColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
        child: Column(children: [
          const SizedBox(height: 60),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(gradient: c.accentGradient, borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 10))]),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          Text('SWAAP', style: GoogleFonts.sora(fontSize: 36, fontWeight: FontWeight.w800, color: c.textPrimary)),
          const SizedBox(height: 4),
          Text('SWU Alternatif App', style: GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 14, letterSpacing: 1)),
          const SizedBox(height: 40),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: c.cardBlur, borderRadius: BorderRadius.circular(24), border: Border.all(color: c.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Login Akademik', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  const SizedBox(height: 6),
                  Text('Masuk dengan akun portal kampus', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                  const SizedBox(height: 24),
                  _buildField(c, userCtrl, 'Username', Icons.badge_outlined, hint: 'NIM / Username'),
                  const SizedBox(height: 14),
                  _buildField(c, passCtrl, 'Password', Icons.lock_outline, obscure: true),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: busy ? null : c.accentGradient, color: busy ? c.surface : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: busy ? null : [BoxShadow(color: c.accent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: ElevatedButton(
                        onPressed: busy ? null : onLogin,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: Text(busy ? 'Memproses...' : 'Masuk', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ),
                  if (log.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(width: double.infinity, padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
                      child: Text(log, style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ]),
      )),
    );
  }

  Widget _buildField(SwaapColors c, TextEditingController ctrl, String label, IconData icon, {String? hint, bool obscure = false}) {
    return TextField(
      controller: ctrl, obscureText: obscure,
      style: TextStyle(color: c.textPrimary),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: TextStyle(color: c.textSecondary),
        hintStyle: TextStyle(color: c.textSecondary.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: c.textSecondary),
        filled: true, fillColor: c.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.accent, width: 1.5)),
      ),
    );
  }
}
