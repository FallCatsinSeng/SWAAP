import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/aspirasi_model.dart';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';
import '../services/pdf_export.dart';

class AspirasiTab extends StatefulWidget {
  final List<Aspirasi> items;
  final bool busy;
  final bool isAdmin;
  final String nim;
  final String nama;
  final ScrollController scrollCtrl;
  final Future<void> Function() onRefresh;
  final Future<void> Function({
    required String sasaran,
    required String kritik,
    required String saran,
    required bool isAnonim,
    required String semester,
    required String jurusan,
  }) onSubmit;
  final Future<void> Function(int) onDelete;
  final Future<void> Function(int id, String status, String reply) onUpdateStatus;

  const AspirasiTab({
    super.key,
    required this.items,
    required this.busy,
    required this.isAdmin,
    required this.nim,
    required this.nama,
    required this.scrollCtrl,
    required this.onRefresh,
    required this.onSubmit,
    required this.onDelete,
    required this.onUpdateStatus,
  });

  @override
  State<AspirasiTab> createState() => _AspirasiTabState();
}

class _AspirasiTabState extends State<AspirasiTab> {
  bool _showMine = false;

  List<Aspirasi> get _displayItems {
    if (!_showMine) return widget.items;
    return widget.items.where((a) => a.nim == widget.nim || (a.isAnonim && a.nim.isEmpty)).toList();
  }

  Future<void> _generatePdf() async {
    await PdfExport.generateAndPrint(_displayItems);
  }

  @override
  Widget build(BuildContext context) {
    final c = SwaapColors.of(context);
    return Stack(
      children: [
        RefreshIndicator(
          color: c.accent,
          backgroundColor: c.surface,
          onRefresh: widget.onRefresh,
          child: ListView(
            controller: widget.scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              _headerSection(c),
              const SizedBox(height: 12),
              _filterChips(c),
              const SizedBox(height: 16),
              if (widget.busy && widget.items.isEmpty)
                _loadingState(c)
              else if (widget.items.isEmpty)
                _emptyState(c)
              else
                ..._displayItems.map((a) => _aspirasiCard(c, a)),
            ],
          ),
        ),
        // FAB to submit
        Positioned(
          right: 16,
          bottom: 16,
          child: _buildFab(c),
        ),
      ],
    );
  }

  Widget _headerSection(SwaapColors c) {
    return Row(
      children: [
        Icon(Icons.campaign_rounded, color: c.accent, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Aspirasi & Aduan',
            style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
        ),
        if (widget.isAdmin) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: c.accentGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Admin', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.print_rounded, color: c.accent, size: 22),
            onPressed: _generatePdf,
            tooltip: 'Cetak Laporan',
          ),
        ]
      ],
    );
  }

  Widget _filterChips(SwaapColors c) {
    return Row(
      children: [
        _chipButton(c, 'Semua', !_showMine, () => setState(() => _showMine = false)),
        const SizedBox(width: 8),
        _chipButton(c, 'Milik Saya', _showMine, () => setState(() => _showMine = true)),
      ],
    );
  }

  Widget _chipButton(SwaapColors c, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.15) : c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? c.accent.withValues(alpha: 0.4) : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? c.accent : c.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _aspirasiCard(SwaapColors c, Aspirasi a) {
    final statusColor = _statusColor(c, a.status);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: name/anonim + status badge
          Row(
            children: [
              // Avatar
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: a.isAnonim ? c.textSecondary.withValues(alpha: 0.15) : c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    a.isAnonim ? Icons.person_off_rounded : Icons.person_rounded,
                    size: 18,
                    color: a.isAnonim ? c.textSecondary : c.accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.displayName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary),
                    ),
                    Text(
                      a.displayInfo,
                      style: TextStyle(fontSize: 11, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              _statusPill(c, a.statusLabel, statusColor),
            ],
          ),
          const SizedBox(height: 12),

          // Admin view: show real identity for anonim
          if (widget.isAdmin && a.isAnonim && a.nim.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_rounded, size: 12, color: c.orange),
                  const SizedBox(width: 4),
                  Text(
                    '${a.nama} (${a.nim})',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.orange),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Sasaran
          _fieldLabel(c, 'Sasaran Kritik'),
          const SizedBox(height: 2),
          Text(a.sasaran, style: TextStyle(fontSize: 13, color: c.textPrimary, height: 1.4)),
          const SizedBox(height: 10),

          // Kritik
          _fieldLabel(c, 'Kritik'),
          const SizedBox(height: 2),
          Text(a.kritik, style: TextStyle(fontSize: 13, color: c.textPrimary, height: 1.4)),
          const SizedBox(height: 10),

          // Saran
          _fieldLabel(c, 'Saran'),
          const SizedBox(height: 2),
          Text(a.saran, style: TextStyle(fontSize: 13, color: c.textPrimary, height: 1.4)),

          const SizedBox(height: 10),
          // Timestamp & Actions
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 12, color: c.textSecondary.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(
                _formatDate(a.createdAt),
                style: TextStyle(fontSize: 10, color: c.textSecondary.withValues(alpha: 0.6)),
              ),
              const Spacer(),
              if (a.status == 'pending' && a.nim == widget.nim && !widget.isAdmin)
                TextButton(
                  onPressed: () => _confirmDelete(c, a),
                  style: TextButton.styleFrom(
                    foregroundColor: c.red,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Hapus', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              if (widget.isAdmin)
                TextButton(
                  onPressed: () => _showUpdateStatusSheet(c, a),
                  style: TextButton.styleFrom(
                    foregroundColor: c.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Update Status', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),

          if (a.adminReply.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.green.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: c.green),
                      const SizedBox(width: 6),
                      Text('Tanggapan Admin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.green)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(a.adminReply, style: TextStyle(fontSize: 12, color: c.textPrimary, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fieldLabel(SwaapColors c, String label) {
    return Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.accent, letterSpacing: 0.3),
    );
  }

  Widget _statusPill(SwaapColors c, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Color _statusColor(SwaapColors c, String status) {
    switch (status) {
      case 'diproses':
        return c.orange;
      case 'selesai':
        return c.green;
      default:
        return c.textSecondary;
    }
  }

  Widget _buildFab(SwaapColors c) {
    return GestureDetector(
      onTap: () => _showSubmitSheet(c),
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: c.accentGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: c.accent.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _emptyState(SwaapColors c) => GlassCard(
    padding: const EdgeInsets.all(32),
    child: Column(children: [
      Icon(Icons.campaign_outlined, size: 40, color: c.textSecondary.withValues(alpha: 0.4)),
      const SizedBox(height: 10),
      Text('Belum ada aspirasi', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: c.textSecondary)),
      const SizedBox(height: 4),
      Text('Jadilah yang pertama menyampaikan!', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.textSecondary.withValues(alpha: 0.6))),
    ]),
  );

  Widget _loadingState(SwaapColors c) => Padding(
    padding: const EdgeInsets.all(40),
    child: Center(child: CircularProgressIndicator(color: c.accent, strokeWidth: 2)),
  );

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── Submit Bottom Sheet ──────────────────────────────────────────────────

  void _showSubmitSheet(SwaapColors c) {
    final sasaranCtrl = TextEditingController();
    final kritikCtrl = TextEditingController();
    final saranCtrl = TextEditingController();
    bool isAnonim = false;
    String selectedSemester = '1';
    String selectedJurusan = 'Teknik Informatika';

    final semesters = List.generate(14, (i) => '${i + 1}');
    final jurusans = [
      'Teknik Informatika',
      'Sistem Informasi',
      'D3 Komputerisasi Akuntansi',
      'D3 Teknik Informatika',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final c = SwaapColors.of(ctx);
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: c.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Icon(Icons.campaign_rounded, color: c.accent, size: 22),
                      const SizedBox(width: 8),
                      Text('Kirim Aspirasi', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: c.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Anonim toggle
                        GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            children: [
                              Icon(
                                isAnonim ? Icons.person_off_rounded : Icons.person_rounded,
                                color: isAnonim ? c.orange : c.accent,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isAnonim ? 'Mode Anonim' : 'Tampilkan Identitas',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary),
                                    ),
                                    Text(
                                      isAnonim ? 'Nama & NIM akan disembunyikan' : 'Nama & NIM akan terlihat',
                                      style: TextStyle(fontSize: 11, color: c.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isAnonim,
                                activeTrackColor: c.orange.withValues(alpha: 0.3),
                                thumbColor: WidgetStateProperty.resolveWith((states) =>
                                  states.contains(WidgetState.selected) ? c.orange : c.textSecondary),
                                onChanged: (v) => setSheetState(() => isAnonim = v),
                              ),
                            ],
                          ),
                        ),

                        // If anonim → show semester & jurusan pickers
                        if (isAnonim) ...[
                          _sheetLabel(c, 'Semester'),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: c.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedSemester,
                                isExpanded: true,
                                dropdownColor: c.surface,
                                style: TextStyle(color: c.textPrimary, fontSize: 14),
                                items: semesters.map((s) => DropdownMenuItem(value: s, child: Text('Semester $s'))).toList(),
                                onChanged: (v) { if (v != null) setSheetState(() => selectedSemester = v); },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _sheetLabel(c, 'Jurusan'),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: c.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedJurusan,
                                isExpanded: true,
                                dropdownColor: c.surface,
                                style: TextStyle(color: c.textPrimary, fontSize: 14),
                                items: jurusans.map((j) => DropdownMenuItem(value: j, child: Text(j, overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (v) { if (v != null) setSheetState(() => selectedJurusan = v); },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Sasaran Kritik
                        _sheetLabel(c, 'Sasaran Kritik'),
                        const SizedBox(height: 6),
                        _sheetField(c, sasaranCtrl, 'Kepada siapa/apa ditujukan...', maxLines: 2),
                        const SizedBox(height: 14),

                        // Kritik
                        _sheetLabel(c, 'Kritik'),
                        const SizedBox(height: 6),
                        _sheetField(c, kritikCtrl, 'Sampaikan kritik Anda...', maxLines: 4),
                        const SizedBox(height: 14),

                        // Saran
                        _sheetLabel(c, 'Saran'),
                        const SizedBox(height: 6),
                        _sheetField(c, saranCtrl, 'Berikan saran perbaikan...', maxLines: 4),
                        const SizedBox(height: 20),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: c.accentGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                if (sasaranCtrl.text.trim().isEmpty ||
                                    kritikCtrl.text.trim().isEmpty ||
                                    saranCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                    content: const Text('Semua field wajib diisi!'),
                                    backgroundColor: c.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ));
                                  return;
                                }
                                Navigator.pop(ctx);
                                await widget.onSubmit(
                                  sasaran: sasaranCtrl.text.trim(),
                                  kritik: kritikCtrl.text.trim(),
                                  saran: saranCtrl.text.trim(),
                                  isAnonim: isAnonim,
                                  semester: isAnonim ? selectedSemester : '',
                                  jurusan: isAnonim ? selectedJurusan : '',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Kirim Aspirasi',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _sheetLabel(SwaapColors c, String label) {
    return Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textPrimary),
    );
  }

  Widget _sheetField(SwaapColors c, TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(color: c.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textSecondary.withValues(alpha: 0.5)),
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.accent, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  void _confirmDelete(SwaapColors c, Aspirasi a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.bg,
        title: Text('Hapus Aspirasi', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus aspirasi ini?', style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete(a.id);
            },
            child: Text('Hapus', style: TextStyle(color: c.red)),
          ),
        ],
      ),
    );
  }

  void _showUpdateStatusSheet(SwaapColors c, Aspirasi a) {
    String selectedStatus = a.status;
    final replyCtrl = TextEditingController(text: a.adminReply);

    final statuses = ['pending', 'diproses', 'selesai', 'ditolak'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final sc = SwaapColors.of(ctx);
          return Container(
            margin: EdgeInsets.only(top: MediaQuery.of(ctx).padding.top + 40),
            decoration: BoxDecoration(
              color: sc.bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: sc.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Update Status', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: sc.textPrimary)),
                      IconButton(icon: Icon(Icons.close_rounded, color: sc.textSecondary), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sheetLabel(sc, 'Status Laporan'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(color: sc.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: sc.border)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedStatus,
                              isExpanded: true,
                              dropdownColor: sc.surface,
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: sc.textSecondary),
                              items: statuses.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase(), style: TextStyle(color: sc.textPrimary)))).toList(),
                              onChanged: (val) { if (val != null) setSheetState(() => selectedStatus = val); },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _sheetLabel(sc, 'Tanggapan / Penjelasan'),
                        const SizedBox(height: 8),
                        _sheetField(sc, replyCtrl, 'Tulis tanggapan untuk pelapor...', maxLines: 4),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(gradient: sc.accentGradient, borderRadius: BorderRadius.circular(14)),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                widget.onUpdateStatus(a.id, selectedStatus, replyCtrl.text.trim());
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                              child: Text('Simpan Update', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}
