import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../models/zoom_info.dart';
import '../models/jadwal_item.dart';
import '../models/presensi_course.dart';
import '../models/aspirasi_model.dart';
import '../services/cred_store.dart';
import '../services/aspirasi_service.dart';
import '../theme/colors.dart';
import 'login_screen.dart';
import 'beranda_tab.dart';
import 'presensi_tab.dart';
import 'aspirasi_tab.dart';

/// Returns the appropriate API base URL for the current platform.
String _apiBase() {
  if (kReleaseMode) return 'http://127.0.0.1:8080';
  if (kIsWeb) return 'http://127.0.0.1:8080';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://127.0.0.1:8080';
  return 'http://127.0.0.1:8080';
}

class MainPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  const MainPage({super.key, required this.isDark, required this.onToggleTheme});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _apiCtrl = TextEditingController(text: _apiBase());
  final _baseCtrl = TextEditingController(text: 'https://smartone.smart-service.co.id');
  final _userCtrl = TextEditingController(), _passCtrl = TextEditingController();
  final _jadwalScroll = ScrollController(), _presensiScroll = ScrollController(), _aspirasiScroll = ScrollController();
  String _phpsessid = '', _log = 'Memuat...';
  String _nama = '', _nim = '';
  bool _busyLogin = false, _busyJadwal = false, _busyPresensi = false, _busyAttend = false, _busyAspirai = false, _initDone = false;
  bool _isAdmin = false;
  int _tabIndex = 0;
  DateTime? _lastSync;
  List<JadwalItem> _jadwalItems = [];
  List<PresensiCourse> _presensiCourses = [];
  String _presensiMsg = '';
  List<Aspirasi> _aspirasiItems = [];

  bool get _loggedIn => _phpsessid.isNotEmpty;
  bool get _busy => _busyLogin || _busyJadwal || _busyPresensi || _busyAttend || _busyAspirai;

  AspirasiService get _aspirasiService => AspirasiService(apiBase: _apiCtrl.text.trim());

  List<JadwalItem> get _filtered {
    final now = DateTime.now();
    final ongoing = _jadwalItems.where((i) => i.isOngoing).toList();
    final upMap = <String, JadwalItem>{};
    for (final i in _jadwalItems.where((i) => i.isUpcoming)) {
      final ex = upMap[i.courseName];
      if (ex == null || (i.startDT != null && ex.startDT != null && i.startDT!.isBefore(ex.startDT!))) upMap[i.courseName] = i;
    }
    final up = upMap.values.toList()..sort((a, b) => (a.startDT ?? now).compareTo(b.startDT ?? now));
    return [...ongoing, ...up];
  }

  ZoomInfo _zoomForCourse(String courseName) {
    final all = _jadwalItems.where((i) => i.courseName == courseName).toList();
    all.sort((a, b) => int.tryParse(b.meeting)?.compareTo(int.tryParse(a.meeting) ?? 0) ?? 0);
    for (final item in all) {
      final z = ZoomInfo.parse(item.room);
      if (z.hasZoom) return z;
    }
    return ZoomInfo(meetingId: '', password: '', roomOnly: '');
  }

  @override
  void initState() { super.initState(); _tryAutoLogin(); }

  @override
  void dispose() {
    _apiCtrl.dispose(); _baseCtrl.dispose(); _userCtrl.dispose(); _passCtrl.dispose();
    _jadwalScroll.dispose(); _presensiScroll.dispose(); _aspirasiScroll.dispose();
    super.dispose();
  }

  Future<void> _tryAutoLogin() async {
    final creds = await CredStore.load();
    if (creds != null) {
      _userCtrl.text = creds['user']!; _passCtrl.text = creds['pass']!;
      if (creds['base']!.isNotEmpty) _baseCtrl.text = creds['base']!;
      setState(() { _initDone = true; _log = 'Auto login...'; });
      await _doLogin(silent: true);
    } else {
      setState(() { _initDone = true; _log = 'Siap login.'; });
    }
  }

  Future<void> _reLogin() async {
    final creds = await CredStore.load();
    if (creds == null) { _logout(); return; }
    _userCtrl.text = creds['user']!; _passCtrl.text = creds['pass']!;
    await _doLogin(silent: true);
  }

  Future<void> _login() async => _doLogin(silent: false);

  Future<void> _doLogin({bool silent = false}) async {
    if (_userCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) { setState(() => _log = 'Username dan password wajib diisi.'); return; }
    setState(() { _busyLogin = true; if (!silent) _log = 'Mengirim login...'; });
    try {
      final r = await http.post(
        Uri.parse('${_apiCtrl.text.trim()}/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'base_url': _baseCtrl.text.trim(), 'username': _userCtrl.text.trim(), 'password': _passCtrl.text,
          'mac_addr': '', 'accept_language': 'en-US,en;q=0.9',
          'user_agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36',
        }),
      ).timeout(const Duration(seconds: 30));
      final p = jsonDecode(r.body) as Map<String, dynamic>;
      final d = p['data'] as Map<String, dynamic>?;
      if (p['ok'] != true || d == null) { setState(() { _phpsessid = ''; _log = 'Login gagal: ${p['error']}'; }); return; }
      final s = '${d['phpsessid'] ?? ''}';
      setState(() { _phpsessid = s; _log = s.isEmpty ? 'PHPSESSID kosong.' : 'Login sukses!'; });
      if (s.isNotEmpty) {
        await CredStore.save(user: _userCtrl.text.trim(), pass: _passCtrl.text, base: _baseCtrl.text.trim());
        await _fetchJadwal(); await _fetchPresensi();
        // After presensi loads NIM, check admin status and load aspirasi
        _checkAdminStatus();
        _fetchAspirai();
      }
    } on TimeoutException { setState(() => _log = 'Timeout login.'); }
    catch (e) { setState(() => _log = 'Error: $e'); }
    finally { setState(() => _busyLogin = false); }
  }

  Future<void> _fetchJadwal() async {
    if (_phpsessid.isEmpty) return; setState(() => _busyJadwal = true);
    try {
      final r = await http.post(
        Uri.parse('${_apiCtrl.text.trim()}/api/jadwal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'base_url': _baseCtrl.text.trim(), 'phpsessid': _phpsessid,
          'path': '/modul_siswa/jadwal_ujian_siswa/jadwal_ujian_siswa_view.php',
          'referer_path': '/modul_siswa/jadwal_ujian_siswa/jadwal_ujian_siswa.php?jenis=MHS&param_menu=&ujian=0&ekstra=0',
          'siswa_program_id': 232,
        }),
      ).timeout(const Duration(seconds: 30));
      final p = jsonDecode(r.body) as Map<String, dynamic>;
      if (p['ok'] != true) {
        if (r.statusCode == 502) { await _reLogin(); if (_loggedIn) return _fetchJadwal(); }
        setState(() => _log = 'Jadwal gagal: ${p['error']}'); return;
      }
      final d = p['data'] as Map<String, dynamic>?; if (d == null) return;
      final items = (d['items'] as List? ?? []).whereType<Map<String, dynamic>>().map(JadwalItem.fromJson).toList();
      setState(() { _jadwalItems = items; _lastSync = DateTime.now(); _log = 'Jadwal dimuat (${items.length} item).'; });
    } catch (e) { setState(() => _log = 'Error jadwal: $e'); }
    finally { setState(() => _busyJadwal = false); }
  }

  Future<void> _fetchPresensi() async {
    if (_phpsessid.isEmpty) return; setState(() => _busyPresensi = true);
    try {
      final r = await http.post(
        Uri.parse('${_apiCtrl.text.trim()}/api/presensi'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'base_url': _baseCtrl.text.trim(), 'phpsessid': _phpsessid}),
      ).timeout(const Duration(seconds: 30));
      final p = jsonDecode(r.body) as Map<String, dynamic>;
      if (p['ok'] != true) { setState(() { _presensiCourses = []; _presensiMsg = 'Gagal: ${p['error']}'; }); return; }
      final d = p['data'] as Map<String, dynamic>?; if (d == null) return;
      final c = (d['courses'] as List? ?? []).whereType<Map<String, dynamic>>().map(PresensiCourse.fromJson).toList();
      final namaBaru = '${d['nama'] ?? ''}';
      final nimBaru = '${d['nim'] ?? ''}';
      setState(() {
        _presensiCourses = c; _presensiMsg = '${d['message'] ?? ''}';
        if (namaBaru.isNotEmpty) _nama = namaBaru;
        if (nimBaru.isNotEmpty) _nim = nimBaru;
      });
    } catch (e) { setState(() { _presensiCourses = []; _presensiMsg = 'Error: $e'; }); }
    finally { setState(() => _busyPresensi = false); }
  }

  Future<void> _submitAttend(PresensiCourse c) async {
    setState(() => _busyAttend = true);
    try {
      final r = await http.post(
        Uri.parse('${_apiCtrl.text.trim()}/api/attend'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'base_url': _baseCtrl.text.trim(), 'phpsessid': _phpsessid,
          'id_krs': c.idKrs, 'yang_ke': c.yangKe, 'id_jadwal': c.idJadwal,
          'nama_mk': c.namaMK, 'perkuliahan': c.perkuliahan,
          'ket_perkuliahan': c.ketPerkuliahan, 'hibrid': c.hibrid,
        }),
      ).timeout(const Duration(seconds: 30));
      final p = jsonDecode(r.body) as Map<String, dynamic>;
      final d = p['data'] as Map<String, dynamic>?;
      final ok = d?['success'] == true;
      final msg = '${d?['message'] ?? p['error'] ?? 'Unknown'}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: ok ? AppColors.green : AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      if (ok) {
        setState(() { _presensiCourses = _presensiCourses.map((x) => x.idKrs == c.idKrs ? x.copyWith(hadir: true) : x).toList(); });
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
    finally { setState(() => _busyAttend = false); }
  }

  // ── Aspirasi Methods ──────────────────────────────────────────────────────

  Future<void> _checkAdminStatus() async {
    if (_nim.isEmpty) return;
    final admin = await _aspirasiService.checkAdmin(nim: _nim);
    if (mounted) setState(() => _isAdmin = admin);
  }

  Future<void> _fetchAspirai() async {
    setState(() => _busyAspirai = true);
    try {
      List<Aspirasi> items;
      if (_isAdmin && _nim.isNotEmpty) {
        items = await _aspirasiService.fetchAdminList(nim: _nim);
      } else {
        items = await _aspirasiService.fetchList();
      }
      if (mounted) setState(() => _aspirasiItems = items);
    } catch (_) {
      // Silently fail — aspirasi is not critical
    } finally {
      if (mounted) setState(() => _busyAspirai = false);
    }
  }

  Future<void> _submitAspirai({
    required String sasaran,
    required String kritik,
    required String saran,
    required bool isAnonim,
    required String semester,
    required String jurusan,
  }) async {
    setState(() => _busyAspirai = true);
    try {
      final result = await _aspirasiService.submit(
        nim: _nim,
        nama: _nama,
        sasaran: sasaran,
        kritik: kritik,
        saran: saran,
        isAnonim: isAnonim,
        semester: semester,
        jurusan: jurusan,
      );
      if (mounted) {
        final ok = result['ok'] == true;
        final msg = ok
            ? (result['data']?['message'] ?? 'Berhasil!')
            : (result['error'] ?? 'Gagal mengirim');
        final c = SwaapColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$msg'),
          backgroundColor: ok ? c.green : c.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        if (ok) await _fetchAspirai();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyAspirai = false);
    }
  }

  Future<void> _deleteAspirasi(int id) async {
    setState(() => _busyAspirai = true);
    try {
      final result = await _aspirasiService.deleteAspirasi(nim: _nim, aspirasiId: id);
      if (mounted) {
        final ok = result['ok'] == true;
        final msg = ok ? 'Aspirasi berhasil dihapus' : (result['error'] ?? 'Gagal menghapus');
        final c = SwaapColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: ok ? c.green : c.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        if (ok) await _fetchAspirai();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busyAspirai = false);
    }
  }

  Future<void> _updateAspirasiStatus(int id, String status, String reply) async {
    setState(() => _busyAspirai = true);
    try {
      final result = await _aspirasiService.updateStatus(nim: _nim, aspirasiId: id, status: status, adminReply: reply);
      if (mounted) {
        final ok = result['ok'] == true;
        final msg = ok ? 'Status berhasil diupdate' : (result['error'] ?? 'Gagal update status');
        final c = SwaapColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: ok ? c.green : c.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        if (ok) await _fetchAspirai();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busyAspirai = false);
    }
  }

  void _logout() async {
    await CredStore.clear();
    setState(() {
      _phpsessid = ''; _jadwalItems = []; _presensiCourses = [];
      _presensiMsg = ''; _lastSync = null; _tabIndex = 0;
      _aspirasiItems = []; _isAdmin = false;
      _log = 'Session dibersihkan.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = SwaapColors.of(context);
    if (!_initDone) return Scaffold(backgroundColor: c.bg, body: Center(child: CircularProgressIndicator(color: c.accent)));

    final content = Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(child: _loggedIn ? _dashboard() : LoginScreen(userCtrl: _userCtrl, passCtrl: _passCtrl, busy: _busy, log: _log, onLogin: _login)),
      bottomNavigationBar: _loggedIn ? _buildBottomNav() : null,
    );

    return Container(
      color: c.outerBg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: content,
        ),
      ),
    );
  }

  void _openAspirasi() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _AspirasiPage(
        isDark: widget.isDark,
        onToggleTheme: widget.onToggleTheme,
        items: _aspirasiItems,
        busy: _busyAspirai,
        isAdmin: _isAdmin,
        nim: _nim,
        nama: _nama,
        onRefresh: _fetchAspirai,
        onSubmit: _submitAspirai,
        onDelete: _deleteAspirasi,
        onUpdateStatus: _updateAspirasiStatus,
      ),
    ));
  }

  Widget _dashboard() => Column(children: [
    _header(),
    Expanded(child: IndexedStack(index: _tabIndex, children: [
      BerandaTab(allItems: _jadwalItems, filteredItems: _filtered, lastSync: _lastSync, busy: _busyJadwal, scrollCtrl: _jadwalScroll, onRefresh: _fetchJadwal, zoomForCourse: _zoomForCourse, onGoPresensi: () => setState(() => _tabIndex = 1), onGoAspirai: _openAspirasi),
      PresensiTab(courses: _presensiCourses, presensiMsg: _presensiMsg, busyPresensi: _busyPresensi, busyAttend: _busyAttend, scrollCtrl: _presensiScroll, onRefresh: _fetchPresensi, onAttend: _submitAttend),
    ])),
  ]);

  Widget _header() {
    final c = SwaapColors.of(context);
    String greeting;
    final hour = DateTime.now().hour;
    if (hour < 12) greeting = 'Selamat Pagi';
    else if (hour < 15) greeting = 'Selamat Siang';
    else if (hour < 18) greeting = 'Selamat Sore';
    else greeting = 'Selamat Malam';

    final displayName = _nama.isNotEmpty ? _nama.split(' ').first : 'Mahasiswa';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(gradient: c.accentGradient, borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(displayName[0].toUpperCase(), style: GoogleFonts.sora(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('$greeting 👋', style: TextStyle(color: c.textSecondary, fontSize: 12)),
          const SizedBox(height: 2),
          Text(displayName, style: GoogleFonts.sora(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
        ])),
        if (_busy)
          Padding(padding: const EdgeInsets.only(right: 4), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))),
        // Theme toggle
        IconButton(
          icon: Icon(widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: c.textSecondary, size: 20),
          onPressed: widget.onToggleTheme,
          tooltip: widget.isDark ? 'Light Mode' : 'Dark Mode',
        ),
        // Logout
        Container(
          decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12)),
          child: IconButton(icon: Icon(Icons.logout_rounded, color: c.textSecondary, size: 20), onPressed: _busy ? null : _logout, tooltip: 'Logout'),
        ),
      ]),
    );
  }

  Widget _buildBottomNav() {
    final c = SwaapColors.of(context);
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      child: NavigationBar(
        height: 70,
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        backgroundColor: Colors.transparent,
        indicatorColor: c.accent.withValues(alpha: 0.15),
        destinations: [
          NavigationDestination(icon: Icon(Icons.home_outlined, color: c.textSecondary), selectedIcon: Icon(Icons.home_rounded, color: c.accent), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.front_hand_outlined, color: c.textSecondary), selectedIcon: Icon(Icons.front_hand, color: c.accent), label: 'Presensi'),
        ],
      ),
    );
  }
}

/// Full-screen Aspirasi page (pushed via Navigator from menu)
class _AspirasiPage extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final List<Aspirasi> items;
  final bool busy;
  final bool isAdmin;
  final String nim;
  final String nama;
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

  const _AspirasiPage({
    required this.isDark,
    required this.onToggleTheme,
    required this.items,
    required this.busy,
    required this.isAdmin,
    required this.nim,
    required this.nama,
    required this.onRefresh,
    required this.onSubmit,
    required this.onDelete,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final c = SwaapColors.of(context);
    return Container(
      color: c.outerBg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Scaffold(
            backgroundColor: c.bg,
            appBar: AppBar(
              backgroundColor: c.surface,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: c.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text('Aspirasi & Aduan', style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
              centerTitle: false,
            ),
            body: SafeArea(
              child: AspirasiTab(
                items: items,
                busy: busy,
                isAdmin: isAdmin,
                nim: nim,
                nama: nama,
                scrollCtrl: ScrollController(),
                onRefresh: onRefresh,
                onSubmit: onSubmit,
                onDelete: onDelete,
                onUpdateStatus: onUpdateStatus,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
