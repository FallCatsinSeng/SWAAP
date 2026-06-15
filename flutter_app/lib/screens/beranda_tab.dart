import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/jadwal_item.dart';
import '../models/zoom_info.dart';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';

class BerandaTab extends StatelessWidget {
  final List<JadwalItem> allItems;
  final List<JadwalItem> filteredItems;
  final DateTime? lastSync;
  final bool busy;
  final ScrollController scrollCtrl;
  final Future<void> Function() onRefresh;
  final ZoomInfo Function(String courseName) zoomForCourse;
  /// Called when user taps the Presensi menu to switch tab
  final VoidCallback? onGoPresensi;

  const BerandaTab({
    super.key,
    required this.allItems,
    required this.filteredItems,
    required this.lastSync,
    required this.busy,
    required this.scrollCtrl,
    required this.onRefresh,
    required this.zoomForCourse,
    this.onGoPresensi,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _menuGrid(context),
          const SizedBox(height: 20),
          _jadwalSection(context),
        ],
      ),
    );
  }

  // ── Grid Menu (like bank apps) ──
  Widget _menuGrid(BuildContext context) {
    final menus = <_MenuItem>[
      _MenuItem(Icons.calendar_month_rounded, 'Jadwal', AppColors.accent, null),
      _MenuItem(Icons.front_hand_rounded, 'Presensi', AppColors.green, onGoPresensi),
      _MenuItem(Icons.school_rounded, 'Nilai', const Color(0xFFFBBF24), null),
      _MenuItem(Icons.assignment_rounded, 'KRS', const Color(0xFFF472B6), null),
      _MenuItem(Icons.account_balance_wallet_rounded, 'Keuangan', const Color(0xFF38BDF8), null),
      _MenuItem(Icons.groups_rounded, 'Organisasi', const Color(0xFFA78BFA), null),
      _MenuItem(Icons.campaign_rounded, 'Aspirasi', const Color(0xFFFB923C), null),
      _MenuItem(Icons.more_horiz_rounded, 'Lainnya', AppColors.textSecondary, null),
    ];

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 14,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: menus.length,
        itemBuilder: (ctx, i) => _menuItem(context, menus[i]),
      ),
    );
  }

  Widget _menuItem(BuildContext context, _MenuItem item) {
    final isActive = item.onTap != null ||
        item.label == 'Jadwal'; // Jadwal is always "active" (we're on beranda)

    return GestureDetector(
      onTap: () {
        if (item.onTap != null) {
          item.onTap!();
        } else if (item.label != 'Jadwal') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${item.label} — Segera hadir!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 1),
          ));
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            style: TextStyle(
              color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Jadwal Hari Ini Section ──
  Widget _jadwalSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.calendar_month_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Text('Jadwal Kuliah',
              style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          if (lastSync != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
              child: Text(
                '${lastSync!.hour.toString().padLeft(2, '0')}:${lastSync!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Text('Aktif & akan datang', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 12),
        if (filteredItems.isEmpty) _emptyState(),
        ...filteredItems.map((item) => _jadwalCard(context, item)),
      ],
    );
  }

  Widget _jadwalCard(BuildContext context, JadwalItem item) {
    final isOngoing = item.isOngoing;
    final color = isOngoing ? AppColors.green : AppColors.accent;
    final label = isOngoing ? 'Berlangsung' : 'Akan Datang';

    var zoom = ZoomInfo.parse(item.room);
    if (!zoom.hasZoom) zoom = zoomForCourse(item.courseName);

    return GlassCard(
      borderColor: color.withValues(alpha: 0.2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(item.courseName,
              style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
          _pill(label, color),
        ]),
        const SizedBox(height: 6),
        Text(item.lecturer, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _infoChip(Icons.meeting_room_outlined, zoom.roomOnly.isNotEmpty ? zoom.roomOnly : '-'),
          _infoChip(Icons.event_outlined, item.date),
          _infoChip(Icons.schedule_outlined, item.time.replaceAll(' WIB', '')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _pill(item.method, item.method.toLowerCase().contains('daring') ? AppColors.orange : AppColors.green),
          const Spacer(),
          Text('Pertemuan ${item.meeting}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ]),
        if (zoom.hasZoom) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.videocam, size: 14, color: AppColors.accent),
                const SizedBox(width: 5),
                Text('Zoom Meeting', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.accent)),
              ]),
              const SizedBox(height: 6),
              if (zoom.meetingId.isNotEmpty) _copyRow(context, 'ID', zoom.meetingId),
              if (zoom.password.isNotEmpty) ...[const SizedBox(height: 4), _copyRow(context, 'Pass', zoom.password)],
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _copyRow(BuildContext ctx, String label, String value) {
    return Row(children: [
      Text('$label: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textPrimary))),
      InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text('$label disalin'), duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating, backgroundColor: AppColors.surface,
          ));
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Icon(Icons.copy, size: 12, color: AppColors.accent),
        ),
      ),
    ]);
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );

  Widget _infoChip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _emptyState() => GlassCard(
    padding: const EdgeInsets.all(32),
    child: Column(children: [
      Icon(Icons.calendar_today_outlined, size: 40, color: AppColors.textSecondary.withValues(alpha: 0.4)),
      const SizedBox(height: 10),
      Text('Tidak ada jadwal aktif', textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      Text('Semua pertemuan sudah lewat', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.6))),
    ]),
  );
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _MenuItem(this.icon, this.label, this.color, this.onTap);
}
