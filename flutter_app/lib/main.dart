import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const LegacyWrapperApp());
}

String _defaultApiBaseUrl() {
  if (kIsWeb) {
    return 'http://localhost:8081';
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8081';
  }
  return 'http://127.0.0.1:8081';
}

int _intFromAny(dynamic v) {
  if (v is int) {
    return v;
  }
  if (v is num) {
    return v.toInt();
  }
  return int.tryParse('$v') ?? 0;
}

class LegacyWrapperApp extends StatelessWidget {
  const LegacyWrapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SWAAP Legacy Portal',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: textTheme,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D78B7),
          brightness: Brightness.light,
        ),
      ),
      home: const LegacyPortalPage(),
    );
  }
}

class JadwalItemModel {
  const JadwalItemModel({
    required this.rowId,
    required this.meeting,
    required this.date,
    required this.time,
    required this.room,
    required this.method,
    required this.courseName,
    required this.lecturer,
  });

  final int rowId;
  final String meeting;
  final String date;
  final String time;
  final String room;
  final String method;
  final String courseName;
  final String lecturer;

  factory JadwalItemModel.fromJson(Map<String, dynamic> json) {
    return JadwalItemModel(
      rowId: (json['row_id'] ?? 0) as int,
      meeting: (json['meeting'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      room: (json['room'] ?? '').toString(),
      method: (json['method'] ?? '').toString(),
      courseName: (json['course_name'] ?? '').toString(),
      lecturer: (json['lecturer'] ?? '').toString(),
    );
  }
}

class JadwalCandidateDebugModel {
  const JadwalCandidateDebugModel({
    required this.url,
    required this.finalUrl,
    required this.redirectChain,
    required this.requestReferer,
    required this.bodyLength,
    required this.statusCode,
    required this.responseHeaders,
    required this.responseRaw,
    required this.viewhisCount,
    required this.courseHeaderCount,
    required this.methodInputCount,
    required this.hasJadwalKuliah,
    required this.itemCount,
    required this.duplicateCount,
    required this.fetchError,
    required this.bodyRaw,
  });

  final String url;
  final String finalUrl;
  final List<String> redirectChain;
  final String requestReferer;
  final int bodyLength;
  final int statusCode;
  final List<String> responseHeaders;
  final String responseRaw;
  final int viewhisCount;
  final int courseHeaderCount;
  final int methodInputCount;
  final bool hasJadwalKuliah;
  final int itemCount;
  final int duplicateCount;
  final String fetchError;
  final String bodyRaw;

  factory JadwalCandidateDebugModel.fromJson(Map<String, dynamic> json) {
    return JadwalCandidateDebugModel(
      url: (json['url'] ?? '').toString(),
      finalUrl: (json['final_url'] ?? '').toString(),
      redirectChain: (json['redirect_chain'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      requestReferer: (json['request_referer'] ?? '').toString(),
      bodyLength: _intFromAny(json['body_len']),
      statusCode: _intFromAny(json['status_code']),
      responseHeaders: (json['response_headers'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      responseRaw: (json['response_raw'] ?? '').toString(),
      viewhisCount: _intFromAny(json['viewhis_count']),
      courseHeaderCount: _intFromAny(json['course_header_count']),
      methodInputCount: _intFromAny(json['method_input_count']),
      hasJadwalKuliah: json['has_jadwal_kuliah'] == true,
      itemCount: _intFromAny(json['item_count']),
      duplicateCount: _intFromAny(json['duplicate_count']),
      fetchError: (json['fetch_error'] ?? '').toString(),
      bodyRaw: (json['body_raw'] ?? '').toString(),
    );
  }
}

class DebugCandidatesPanel extends StatelessWidget {
  const DebugCandidatesPanel({
    super.key,
    required this.candidates,
    this.onCopy,
  });

  final List<JadwalCandidateDebugModel> candidates;
  final Future<void> Function(JadwalCandidateDebugModel candidate)? onCopy;

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCFE4EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debug Kandidat (Raw HTML)',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF1D5273),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Buka tiap kandidat untuk lihat body HTML penuh yang diterima parser.',
            style: TextStyle(color: Color(0xFF5A7383), fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          ...candidates.map(_candidateTile),
        ],
      ),
    );
  }

  Widget _candidateTile(JadwalCandidateDebugModel c) {
    final source = c.finalUrl.isNotEmpty ? c.finalUrl : c.url;
    final sourceShort = source.length > 92
        ? '${source.substring(0, 92)}...'
        : source;

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(
        sourceShort.isEmpty ? '-' : sourceShort,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      subtitle: Text(
        c.fetchError.isNotEmpty
            ? 'error=${c.fetchError}'
            : 'http=${c.statusCode}, items=${c.itemCount}, dup=${c.duplicateCount}, viewhis=${c.viewhisCount}, header=${c.courseHeaderCount}, method=${c.methodInputCount}',
        style: const TextStyle(fontSize: 12),
      ),
      children: [
        if (c.redirectChain.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: SelectableText(
              'redirect_chain: ${c.redirectChain.join(' -> ')}',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF4E6575),
                fontSize: 12,
              ),
            ),
          ),
        if (onCopy != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: c.bodyRaw.isEmpty ? null : () => onCopy!(c),
              icon: const Icon(Icons.copy_all_rounded),
              label: const Text('Copy HTML'),
            ),
          ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD4E6F0)),
          ),
          child: SizedBox(
            height: 220,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: SelectableText(
                  c.bodyRaw.isEmpty ? '(kosong)' : c.bodyRaw,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LegacyPortalPage extends StatefulWidget {
  const LegacyPortalPage({super.key});

  @override
  State<LegacyPortalPage> createState() => _LegacyPortalPageState();
}

class _LegacyPortalPageState extends State<LegacyPortalPage> {
  final _apiBaseController = TextEditingController(text: _defaultApiBaseUrl());
  final _legacyBaseController = TextEditingController(
    text: 'https://smartone.smart-service.co.id',
  );

  final _warmupPathController = TextEditingController(text: '/swu.php');
  final _refererPathController = TextEditingController(
    text: '/smart_school_biasa_2019.php',
  );
  final _jadwalPathController = TextEditingController(
    text: '/modul_siswa/jadwal_ujian_siswa/jadwal_ujian_siswa_view.php',
  );
  final _jadwalRefererController = TextEditingController(
    text:
        '/modul_siswa/jadwal_ujian_siswa/jadwal_ujian_siswa.php?jenis=MHS&param_menu=&ujian=0&ekstra=0',
  );
  final _siswaProgramIdController = TextEditingController(text: '232');

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _macAddrController = TextEditingController();

  String _phpsessid = '';
  String _log = 'Siap login.';
  int _loginStatusCode = 0;
  int _jadwalStatusCode = 0;
  bool _isBusyLogin = false;
  bool _isBusyJadwal = false;
  DateTime? _lastSync;
  List<JadwalItemModel> _jadwalItems = const [];
  List<JadwalCandidateDebugModel> _jadwalCandidates = const [];

  bool get _isBusy => _isBusyLogin || _isBusyJadwal;
  bool get _isLoggedIn => _phpsessid.isNotEmpty;

  @override
  void dispose() {
    _apiBaseController.dispose();
    _legacyBaseController.dispose();
    _warmupPathController.dispose();
    _refererPathController.dispose();
    _jadwalPathController.dispose();
    _jadwalRefererController.dispose();
    _siswaProgramIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _macAddrController.dispose();
    super.dispose();
  }

  Future<void> _loginAndLoadJadwal() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() {
        _log = 'Username dan password wajib diisi.';
      });
      return;
    }

    setState(() {
      _isBusyLogin = true;
      _log = 'Cek wrapper API...';
    });

    try {
      final apiHealthError = await _checkApiHealth();
      if (apiHealthError != null) {
        setState(() {
          _log = apiHealthError;
        });
        return;
      }

      setState(() {
        _log = 'Mengirim login request...';
      });

      final response = await http
          .post(
            Uri.parse('${_apiBaseController.text.trim()}/api/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'base_url': _legacyBaseController.text.trim(),
              'warmup_path': _warmupPathController.text.trim(),
              'referer_path': _refererPathController.text.trim(),
              'username': _usernameController.text.trim(),
              'password': _passwordController.text,
              'mac_addr': _macAddrController.text.trim(),
              'accept_language': 'en-US,en;q=0.9',
              'user_agent':
                  'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36',
            }),
          )
          .timeout(const Duration(seconds: 30));

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final ok = payload['ok'] == true;
      final data = payload['data'] as Map<String, dynamic>?;
      final error = payload['error']?.toString() ?? 'unknown error';

      if (!ok || data == null) {
        setState(() {
          _phpsessid = '';
          _loginStatusCode = response.statusCode;
          _log = 'Login gagal: $error';
        });
        return;
      }

      final sess = (data['phpsessid'] ?? '').toString();
      setState(() {
        _phpsessid = sess;
        _loginStatusCode = (data['status_code'] ?? response.statusCode) as int;
        _log = sess.isEmpty
            ? 'Login terproses tapi PHPSESSID kosong.'
            : 'Login sukses. Memuat jadwal kuliah...';
      });

      if (sess.isNotEmpty) {
        await _fetchJadwal(autoTriggered: true);
      }
    } on TimeoutException {
      setState(() {
        _log =
            'Timeout login (>30s). Cek koneksi wrapper API atau endpoint legacy.';
      });
    } catch (e) {
      setState(() {
        _log = 'Error login: $e';
      });
    } finally {
      setState(() {
        _isBusyLogin = false;
      });
    }
  }

  Future<void> _fetchJadwal({bool autoTriggered = false}) async {
    if (_phpsessid.isEmpty) {
      setState(() {
        _log = 'Belum ada PHPSESSID. Login dulu.';
      });
      return;
    }

    setState(() {
      _isBusyJadwal = true;
      if (!autoTriggered) {
        _log = 'Mengambil jadwal kuliah...';
      }
    });

    try {
      final response = await http
          .post(
            Uri.parse('${_apiBaseController.text.trim()}/api/jadwal'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'base_url': _legacyBaseController.text.trim(),
              'phpsessid': _phpsessid,
              'debug_full_html': true,
              'path': _jadwalPathController.text.trim(),
              'referer_path': _jadwalRefererController.text.trim(),
              'siswa_program_id':
                  int.tryParse(_siswaProgramIdController.text.trim()) ?? 232,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final ok = payload['ok'] == true;
      final data = payload['data'] as Map<String, dynamic>?;
      final error = payload['error']?.toString() ?? 'unknown error';

      if (!ok || data == null) {
        setState(() {
          _jadwalStatusCode = response.statusCode;
          _jadwalCandidates = const [];
          _log = 'Fetch jadwal gagal: $error';
        });
        return;
      }

      final itemsRaw = (data['items'] as List<dynamic>? ?? const []);
      final items = itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(JadwalItemModel.fromJson)
          .toList(growable: false);
      final bodyPreview = (data['body_preview'] ?? '').toString();
      final bootstrapURL = (data['bootstrap_url'] ?? '').toString();
      final sourceURL = (data['source_url'] ?? '').toString();
      final debug = (data['debug'] as Map<String, dynamic>? ?? const {});
      final viewhisCount = _toInt(debug['viewhis_count']);
      final courseHeaderCount = _toInt(debug['course_header_count']);
      final methodInputCount = _toInt(debug['method_input_count']);
      final hasJadwalKuliah = debug['has_jadwal_kuliah'] == true;
      final duplicateCount = _toInt(debug['duplicate_count']);
      final candidatesRaw = (debug['candidates'] as List<dynamic>? ?? const []);
      final candidates = candidatesRaw
          .whereType<Map<String, dynamic>>()
          .map(JadwalCandidateDebugModel.fromJson)
          .toList(growable: false);
      final candidatesSummary = _debugCandidatesSummary(debug['candidates']);

      setState(() {
        _jadwalStatusCode = (data['status_code'] ?? response.statusCode) as int;
        _jadwalItems = items;
        _jadwalCandidates = candidates;
        _lastSync = DateTime.now();
        _log = items.isEmpty
            ? _buildEmptyJadwalHint(
                bodyPreview: bodyPreview,
                bootstrapURL: bootstrapURL,
                sourceURL: sourceURL,
                viewhisCount: viewhisCount,
                courseHeaderCount: courseHeaderCount,
                methodInputCount: methodInputCount,
                hasJadwalKuliah: hasJadwalKuliah,
                candidatesSummary: candidatesSummary,
              )
            : duplicateCount > 0
            ? 'Jadwal berhasil dimuat (${items.length} item, $duplicateCount duplikat dari sistem legacy disaring).'
            : 'Jadwal berhasil dimuat (${items.length} item).';
      });
    } on TimeoutException {
      setState(() {
        _jadwalCandidates = const [];
        _log = 'Timeout fetch jadwal (>30s).';
      });
    } catch (e) {
      setState(() {
        _jadwalCandidates = const [];
        _log = 'Error fetch jadwal: $e';
      });
    } finally {
      setState(() {
        _isBusyJadwal = false;
      });
    }
  }

  void _logout() {
    setState(() {
      _phpsessid = '';
      _jadwalItems = const [];
      _jadwalCandidates = const [];
      _lastSync = null;
      _loginStatusCode = 0;
      _jadwalStatusCode = 0;
      _log = 'Session dibersihkan.';
    });
  }

  Future<String?> _checkApiHealth() async {
    var base = _apiBaseController.text.trim();
    if (base.isEmpty ||
        (!base.startsWith('http://') && !base.startsWith('https://'))) {
      return 'Wrapper API URL tidak valid. Contoh: http://localhost:8081';
    }

    if (kIsWeb && base.contains('10.0.2.2')) {
      base = base.replaceFirst('10.0.2.2', 'localhost');
      _apiBaseController.text = base;
    }

    try {
      final response = await http
          .get(Uri.parse('$base/health'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null;
      }
      return 'Health check gagal (HTTP ${response.statusCode}) di $base/health';
    } on TimeoutException {
      return 'Timeout saat cek $base/health';
    } catch (e) {
      return 'Gagal akses wrapper API: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE9F6FF), Color(0xFFF9FCF7)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -120,
              top: -90,
              child: _ambientOrb(const Color(0x4D23A9E8), 260),
            ),
            Positioned(
              right: -90,
              bottom: -120,
              child: _ambientOrb(const Color(0x3310C4A6), 280),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 1080;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1220),
                        child: isDesktop
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: _buildShowcasePanel(),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(flex: 6, child: _buildMainPanel()),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildShowcasePanel(),
                                  const SizedBox(height: 14),
                                  _buildMainPanel(),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ambientOrb(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size),
        ),
      ),
    );
  }

  Widget _buildShowcasePanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E74B2), Color(0xFF1E9EDC)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F1A4A66),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SWAAP Legacy Portal',
            style: GoogleFonts.sora(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Login real session + monitoring jadwal perkuliahan dari sistem legacy.',
            style: TextStyle(
              color: Color(0xFFEAF7FF),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          _featureTile(
            'Session-Based Auth',
            'Ambil PHPSESSID otomatis dari flow intercept.',
          ),
          _featureTile(
            'Jadwal Terstruktur',
            'HTML jadwal diparsing jadi data siap pakai.',
          ),
          _featureTile(
            'Fast Debug Loop',
            'Status code + log proses selalu terlihat.',
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: Text(
              _isLoggedIn
                  ? 'Session aktif: ${_shortSession(_phpsessid)}'
                  : 'Belum ada session aktif.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureTile(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: Color(0xFFE0FF74),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFD4EDFA),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xF7FFFFFF),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD4EAF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140B3650),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isLoggedIn ? 'Dashboard Jadwal' : 'Login Akademik',
                  style: GoogleFonts.sora(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F4F7B),
                  ),
                ),
              ),
              if (_isBusy)
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isLoggedIn
                ? 'Session aktif dan siap sinkronisasi jadwal.'
                : 'Masuk dengan kredensial, lalu sistem akan otomatis menarik jadwal.',
            style: const TextStyle(color: Color(0xFF4D6B7C)),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            child: _isLoggedIn ? _buildJadwalView() : _buildLoginView(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginView() {
    return Column(
      key: const ValueKey('login_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _textField(
          _usernameController,
          'Username',
          hint: 'Contoh: STI202303534',
          leading: Icons.badge_outlined,
        ),
        _textField(
          _passwordController,
          'Password',
          obscureText: true,
          leading: Icons.lock_outline,
        ),
        _textField(
          _macAddrController,
          'MAC Address (opsional)',
          leading: Icons.memory,
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: const EdgeInsets.only(bottom: 10),
          title: const Text(
            'Pengaturan Endpoint',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'Base URL, warmup path, referer, dan path jadwal',
          ),
          children: [
            _textField(
              _apiBaseController,
              'Wrapper API Base URL',
              leading: Icons.router_outlined,
            ),
            _textField(
              _legacyBaseController,
              'Legacy Base URL',
              leading: Icons.cloud_outlined,
            ),
            _textField(
              _warmupPathController,
              'Warmup Path',
              leading: Icons.play_circle_outline,
            ),
            _textField(
              _refererPathController,
              'Referer Path Login',
              leading: Icons.link,
            ),
            _textField(
              _jadwalPathController,
              'Path Jadwal View',
              leading: Icons.table_rows_outlined,
            ),
            _textField(
              _jadwalRefererController,
              'Referer Jadwal',
              leading: Icons.reply_outlined,
            ),
            _textField(
              _siswaProgramIdController,
              'Siswa Program ID',
              hint: '232 (jadwal kuliah), sesuaikan jika mode lain',
              leading: Icons.tag,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isBusy ? null : _loginAndLoadJadwal,
            icon: const Icon(Icons.login_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Login Dan Muat Jadwal'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _statusAndLogPanel(),
      ],
    );
  }

  Widget _buildJadwalView() {
    return Column(
      key: const ValueKey('jadwal_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _statusChip('HTTP Login', _loginStatusCode),
            _statusChip('HTTP Jadwal', _jadwalStatusCode),
            Chip(
              label: Text('Session ${_shortSession(_phpsessid)}'),
              backgroundColor: const Color(0xFFE7F4FF),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF6FBFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCCE5F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PHPSESSID',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SelectableText(_phpsessid),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _isBusy ? null : _fetchJadwal,
              icon: const Icon(Icons.sync),
              label: const Text('Refresh Jadwal'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _isBusy ? null : _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
            const Spacer(),
            if (_lastSync != null)
              Text(
                'Last sync ${_formatTime(_lastSync!)}',
                style: const TextStyle(
                  color: Color(0xFF627C8A),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _statusAndLogPanel(),
        if (_jadwalCandidates.isNotEmpty) ...[
          const SizedBox(height: 12),
          DebugCandidatesPanel(
            candidates: _jadwalCandidates,
            onCopy: _copyCandidateHTML,
          ),
        ],
        const SizedBox(height: 14),
        if (_jadwalItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1DFB0)),
            ),
            child: const Text(
              'Belum ada data jadwal. Coba klik "Refresh Jadwal".',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          )
        else
          ..._jadwalItems.map(_jadwalCard),
      ],
    );
  }

  Widget _statusAndLogPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCFE4EF)),
      ),
      child: Text(_log, style: const TextStyle(height: 1.4)),
    );
  }

  Widget _jadwalCard(JadwalItemModel item) {
    final method = item.method.toLowerCase();
    final accent = method.contains('daring')
        ? const Color(0xFF7A4E00)
        : const Color(0xFF0B4E2E);
    final bg = method.contains('daring')
        ? const Color(0xFFFFF5E5)
        : const Color(0xFFEAFBF0);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.courseName.isEmpty ? 'Mata Kuliah' : item.courseName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF104A70),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.method.isEmpty ? 'N/A' : item.method,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.lecturer.isEmpty ? '-' : item.lecturer,
            style: const TextStyle(color: Color(0xFF517082), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaPill(
                'Pertemuan ${item.meeting.isEmpty ? '-' : item.meeting}',
              ),
              _metaPill(item.date.isEmpty ? '-' : item.date),
              _metaPill(item.time.isEmpty ? '-' : item.time),
              _metaPill(item.room.isEmpty ? '-' : item.room),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF28536A),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? hint,
    bool obscureText = false,
    IconData? leading,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: leading == null ? null : Icon(leading),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _statusChip(String label, int code) {
    final hasCode = code > 0;
    final success = code >= 200 && code < 300;
    return Chip(
      label: Text(hasCode ? '$label: $code' : '$label: -'),
      backgroundColor: !hasCode
          ? const Color(0xFFEBF0F3)
          : (success ? const Color(0xFFDFF8E5) : const Color(0xFFFFE2E2)),
      side: const BorderSide(color: Colors.transparent),
    );
  }

  Future<void> _copyCandidateHTML(JadwalCandidateDebugModel candidate) async {
    await Clipboard.setData(ClipboardData(text: candidate.bodyRaw));
    if (!mounted) {
      return;
    }
    final source = candidate.finalUrl.isNotEmpty
        ? candidate.finalUrl
        : candidate.url;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'HTML kandidat disalin (${source.length > 48 ? '${source.substring(0, 48)}...' : source})',
        ),
      ),
    );
  }

  String _shortSession(String sid) {
    if (sid.length <= 12) {
      return sid;
    }
    return '${sid.substring(0, 8)}...${sid.substring(sid.length - 4)}';
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _buildEmptyJadwalHint({
    required String bodyPreview,
    required String bootstrapURL,
    required String sourceURL,
    required int viewhisCount,
    required int courseHeaderCount,
    required int methodInputCount,
    required bool hasJadwalKuliah,
    required String candidatesSummary,
  }) {
    final p = bodyPreview.toLowerCase();
    final stats =
        'stats(viewhis=$viewhisCount, header=$courseHeaderCount, method=$methodInputCount)';
    final src = sourceURL.isEmpty ? '' : ' source=$sourceURL';
    final cands = candidatesSummary.isEmpty
        ? ''
        : ' candidates=$candidatesSummary';

    if (viewhisCount > 0 && courseHeaderCount > 0 && methodInputCount > 0) {
      return 'Data jadwal terdeteksi tapi parser belum match penuh. $stats$src$cands';
    }
    if (p.contains('viewhis(')) {
      return 'Jadwal terambil, tapi parser belum cocok penuh. $stats$src$cands';
    }
    if (p.contains('location.replace(') || p.contains('my_aplikasi_menu')) {
      return 'Masih mentok di halaman menu/redirect. Jalur bootstrap jadwal kemungkinan belum lengkap. $stats$src$cands';
    }
    if (hasJadwalKuliah && viewhisCount == 0) {
      return 'Halaman jadwal terbuka tapi item kosong. Bisa jadi mode terpilih bukan yang ada datanya (coba ubah referer `ujian=0/1` atau `Siswa Program ID`). $stats$src$cands';
    }
    if (bootstrapURL.isNotEmpty) {
      return 'Jadwal berhasil diambil tapi item tidak terdeteksi. bootstrap=$bootstrapURL, $stats$src$cands';
    }
    return 'Jadwal berhasil diambil tapi item tidak terdeteksi. $stats$src$cands';
  }

  String _debugCandidatesSummary(dynamic raw) {
    final list = raw is List ? raw : const [];
    if (list.isEmpty) {
      return '';
    }
    final parts = <String>[];
    for (final entry in list.take(3)) {
      if (entry is! Map) {
        continue;
      }
      final url = (entry['url'] ?? '').toString();
      final status = _toInt(entry['status_code']);
      final viewhis = _toInt(entry['viewhis_count']);
      final header = _toInt(entry['course_header_count']);
      final method = _toInt(entry['method_input_count']);
      final items = _toInt(entry['item_count']);
      final fetchError = (entry['fetch_error'] ?? '').toString();
      final shortUrl = url.length > 52 ? '${url.substring(0, 52)}...' : url;
      if (fetchError.isNotEmpty) {
        parts.add('err($shortUrl)');
      } else {
        parts.add('$status:$items/$viewhis/$header/$method@$shortUrl');
      }
    }
    return parts.join(' | ');
  }

  int _toInt(dynamic v) {
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.toInt();
    }
    return int.tryParse('$v') ?? 0;
  }
}
