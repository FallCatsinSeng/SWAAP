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
    super.key, required this.courses, required this.presensiMsg,
    required this.busyPresensi, required this.busyAttend, required this.scrollCtrl,
    required this.onRefresh, required this.onAttend,
  });

  @override
  Widget build(BuildContext context) {
    final c = SwaapColors.of(context);
    return RefreshIndicator(
      color: c.accent, backgroundColor: c.surface, onRefresh: onRefresh,
      child: ListView(controller: scrollCtrl, padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Icon(Icons.front_hand_rounded, color: c.green, size: 22), const SizedBox(width: 8),
          Text('Presensi', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const Spacer(),
          IconButton(icon: Icon(Icons.refresh_rounded, color: c.textSecondary), onPressed: busyPresensi ? null : onRefresh),
        ]),
        const SizedBox(height: 4),
        Text('Mata kuliah aktif saat ini', style: TextStyle(color: c.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        if (busyPresensi) Center(child: Padding(padding: const EdgeInsets.all(40), child: CircularProgressIndicator(color: c.accent))),
        if (!busyPresensi && courses.isEmpty) _emptyState(c),
        ...courses.map((course) => _presensiCard(context, c, course)),
      ]),
    );
  }

  Widget _presensiCard(BuildContext context, SwaapColors c, PresensiCourse course) {
    final color = course.hadir ? c.accent : c.green;
    return GlassCard(
      borderColor: color.withValues(alpha: 0.2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(course.namaMK, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 6),
        Text('Pertemuan ke-${course.yangKe}', style: TextStyle(color: c.textSecondary, fontSize: 13)),
        if (course.ketPerkuliahan.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(course.ketPerkuliahan, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
        const SizedBox(height: 16),
        if (course.hadir)
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.accent.withValues(alpha: 0.2))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle_rounded, color: c.accent, size: 20), const SizedBox(width: 8),
              Text('Sudah Absen', style: GoogleFonts.sora(color: c.accent, fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
          )
        else
          SizedBox(
            width: double.infinity, height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: c.greenGradient, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: c.green.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
              child: ElevatedButton.icon(
                onPressed: busyAttend ? null : () => _confirmAttend(context, c, course),
                icon: const Icon(Icons.front_hand, color: Colors.white),
                label: Text(busyAttend ? 'Memproses...' : 'Hadir', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ),
      ]),
    );
  }

  void _confirmAttend(BuildContext context, SwaapColors c, PresensiCourse course) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: c.cardBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Konfirmasi Presensi', style: GoogleFonts.sora(color: c.textPrimary, fontWeight: FontWeight.w700)),
      content: Text('Presensi hadir untuk:\n\n${course.namaMK}\nPertemuan ke-${course.yangKe}?', style: TextStyle(color: c.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: TextStyle(color: c.textSecondary))),
        FilledButton(onPressed: () { Navigator.pop(ctx); onAttend(course); }, style: FilledButton.styleFrom(backgroundColor: c.green), child: const Text('Ya, Hadir')),
      ],
    ));
  }

  Widget _emptyState(SwaapColors c) => GlassCard(
    padding: const EdgeInsets.all(40),
    child: Column(children: [
      Icon(Icons.front_hand_outlined, size: 44, color: c.textSecondary.withValues(alpha: 0.4)),
      const SizedBox(height: 12),
      Text(presensiMsg.isNotEmpty ? presensiMsg : 'Tidak ada matkul aktif', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: c.textSecondary)),
      const SizedBox(height: 4),
      Text('Presensi tersedia saat jam kuliah', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.textSecondary.withValues(alpha: 0.6))),
    ]),
  );
}
