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
    super.key,
    required this.userCtrl,
    required this.passCtrl,
    required this.busy,
    required this.log,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(children: [
            const SizedBox(height: 60),
            // Logo area
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 10)),
                ],
              ),
              child: const Icon(Icons.school_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            Text('SWAAP', style: GoogleFonts.sora(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('SWU Alternatif App', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 14, letterSpacing: 1)),
            const SizedBox(height: 40),
            // Login card
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Login Akademik', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text('Masuk dengan akun portal kampus', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 24),
                    _buildField(userCtrl, 'Username', Icons.badge_outlined, hint: 'NIM / Username'),
                    const SizedBox(height: 14),
                    _buildField(passCtrl, 'Password', Icons.lock_outline, obscure: true),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: busy ? null : AppColors.accentGradient,
                          color: busy ? AppColors.surface : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: busy ? null : [
                            BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: busy ? null : onLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(busy ? 'Memproses...' : 'Masuk', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ),
                    if (log.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity, padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                        child: Text(log, style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {String? hint, bool obscure = false}) {
    return TextField(
      controller: ctrl, obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        filled: true, fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
      ),
    );
  }
}
