import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/presensi_course.dart';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';

class PresensiTab extends StatelessWidget {
  final List<PresensiCourse> courses;
  final String presensiMsg;
  final bool busyPresensi;
  final bool busyAttend;
  final ScrollController scrollCtrl;
  final Future<void> Function() onRefresh;
  final void Function(PresensiCourse c) onAttend;

  const PresensiTab({
    super.key,
    required this.courses,
    required this.presensiMsg,
    required this.busyPresensi,
    required this.busyAttend,
    required this.scrollCtrl,
    required this.onRefresh,
    required this.onAttend,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Icon(Icons.front_hand_rounded, color: AppColors.green, size: 22),
            const SizedBox(width: 8),
            Text('Presensi', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              onPressed: busyPresensi ? null : onRefresh,
            ),
          ]),
          const SizedBox(height: 4),
          Text('Mata kuliah aktif saat ini', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          if (busyPresensi)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.accent))),
          if (!busyPresensi && courses.isEmpty)
            _emptyState(),
          ...courses.map((c) => _presensiCard(context, c)),
        ],
      ),
    );
  }

  Widget _presensiCard(BuildContext context, PresensiCourse c) {
    final color = c.hadir ? AppColors.accent : AppColors.green;

    return GlassCard(
      borderColor: color.withValues(alpha: 0.2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.namaMK, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text('Pertemuan ke-${c.yangKe}', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        if (c.ketPerkuliahan.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(c.ketPerkuliahan, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
        const SizedBox(height: 16),
        if (c.hadir)
          // Already attended
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text('Sudah Absen', style: GoogleFonts.sora(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
          )
        else
          // Attend button
          SizedBox(
            width: double.infinity, height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.greenGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: ElevatedButton.icon(
                onPressed: busyAttend ? null : () => _confirmAttend(context, c),
                icon: const Icon(Icons.front_hand, color: Colors.white),
                label: Text(busyAttend ? 'Memproses...' : 'Hadir', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ),
      ]),
    );
  }

  void _confirmAttend(BuildContext context, PresensiCourse c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Konfirmasi Presensi', style: GoogleFonts.sora(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Presensi hadir untuk:\n\n${c.namaMK}\nPertemuan ke-${c.yangKe}?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
          FilledButton(
            onPressed: () { Navigator.pop(ctx); onAttend(c); },
            style: FilledButton.styleFrom(backgroundColor: AppColors.green),
            child: const Text('Ya, Hadir'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => GlassCard(
    padding: const EdgeInsets.all(40),
    child: Column(children: [
      Icon(Icons.front_hand_outlined, size: 44, color: AppColors.textSecondary.withValues(alpha: 0.4)),
      const SizedBox(height: 12),
      Text(presensiMsg.isNotEmpty ? presensiMsg : 'Tidak ada matkul aktif', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      Text('Presensi tersedia saat jam kuliah', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.6))),
    ]),
  );
}
