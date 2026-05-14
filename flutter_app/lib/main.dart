import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const SwaapApp());

String _apiBase() {
  if (kIsWeb) return 'http://localhost:8081';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8081';
  return 'http://127.0.0.1:8081';
}

// ── Models ──

class JadwalItem {
  final int rowId;
  final String meeting, date, time, room, method, courseName, lecturer;
  const JadwalItem({required this.rowId, required this.meeting, required this.date, required this.time, required this.room, required this.method, required this.courseName, required this.lecturer});

  DateTime? get startDT => _parseStart();
  DateTime? get endDT => _parseEnd();
  bool get isOngoing { final n=DateTime.now(); final s=startDT, e=endDT; return s!=null&&e!=null&&n.isAfter(s)&&n.isBefore(e); }
  bool get isUpcoming { final s=startDT; return s!=null&&DateTime.now().isBefore(s); }

  DateTime? _parseStart() { try { final d=date.split('-'); final t=time.split('-')[0].trim().replaceAll('.',':').split(':'); return DateTime(int.parse(d[2]),int.parse(d[1]),int.parse(d[0]),int.parse(t[0]),int.parse(t[1])); } catch(_){return null;} }
  DateTime? _parseEnd() { try { final d=date.split('-'); final t=time.split('-')[1].trim().split(' ')[0].replaceAll('.',':').split(':'); return DateTime(int.parse(d[2]),int.parse(d[1]),int.parse(d[0]),int.parse(t[0]),int.parse(t[1])); } catch(_){return null;} }

  factory JadwalItem.fromJson(Map<String,dynamic> j) => JadwalItem(
    rowId:(j['row_id']??0) as int, meeting:'${j['meeting']??''}', date:'${j['date']??''}',
    time:'${j['time']??''}', room:'${j['room']??''}', method:'${j['method']??''}',
    courseName:'${j['course_name']??''}', lecturer:'${j['lecturer']??''}',
  );
}

class PresensiCourse {
  final int idKrs, yangKe, idJadwal, hibrid;
  final String namaMK, perkuliahan, ketPerkuliahan;
  const PresensiCourse({required this.idKrs, required this.yangKe, required this.idJadwal, required this.hibrid, required this.namaMK, required this.perkuliahan, required this.ketPerkuliahan});
  factory PresensiCourse.fromJson(Map<String,dynamic> j) => PresensiCourse(
    idKrs:(j['id_krs']??0) as int, yangKe:(j['yang_ke']??0) as int, idJadwal:(j['id_jadwal']??0) as int,
    hibrid:(j['hibrid']??0) as int, namaMK:'${j['nama_mk']??''}', perkuliahan:'${j['perkuliahan']??''}',
    ketPerkuliahan:'${j['ket_perkuliahan']??''}',
  );
}

// ── App ──

class SwaapApp extends StatelessWidget {
  const SwaapApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SWAAP',
      theme: ThemeData(useMaterial3:true, textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D78B7))),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _apiCtrl = TextEditingController(text: _apiBase());
  final _baseCtrl = TextEditingController(text: 'https://smartone.smart-service.co.id');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _macCtrl = TextEditingController();

  String _phpsessid = '';
  String _log = 'Siap login.';
  bool _busyLogin = false;
  bool _busyJadwal = false;
  bool _busyPresensi = false;
  bool _busyAttend = false;
  int _tabIndex = 0;
  DateTime? _lastSync;
  List<JadwalItem> _jadwalItems = [];
  List<PresensiCourse> _presensiCourses = [];
  String _presensiMsg = '';

  bool get _loggedIn => _phpsessid.isNotEmpty;
  bool get _busy => _busyLogin||_busyJadwal||_busyPresensi||_busyAttend;

  List<JadwalItem> get _filtered {
    final now = DateTime.now();
    final ongoing = _jadwalItems.where((i)=>i.isOngoing).toList();
    final upMap = <String,JadwalItem>{};
    for (final i in _jadwalItems.where((i)=>i.isUpcoming)) {
      final ex = upMap[i.courseName];
      if (ex==null||(i.startDT!=null&&ex.startDT!=null&&i.startDT!.isBefore(ex.startDT!))) upMap[i.courseName]=i;
    }
    final up = upMap.values.toList()..sort((a,b)=>(a.startDT??now).compareTo(b.startDT??now));
    return [...ongoing,...up];
  }

  @override void dispose() { _apiCtrl.dispose(); _baseCtrl.dispose(); _userCtrl.dispose(); _passCtrl.dispose(); _macCtrl.dispose(); super.dispose(); }

  // ── API Calls ──

  Future<void> _login() async {
    if (_userCtrl.text.trim().isEmpty||_passCtrl.text.trim().isEmpty) { setState(()=>_log='Username dan password wajib diisi.'); return; }
    setState((){ _busyLogin=true; _log='Mengirim login...'; });
    try {
      final r = await http.post(Uri.parse('${_apiCtrl.text.trim()}/api/login'),
        headers:{'Content-Type':'application/json'},
        body:jsonEncode({'base_url':_baseCtrl.text.trim(),'username':_userCtrl.text.trim(),'password':_passCtrl.text,'mac_addr':_macCtrl.text.trim(),
          'accept_language':'en-US,en;q=0.9','user_agent':'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36'}),
      ).timeout(const Duration(seconds:30));
      final p = jsonDecode(r.body) as Map<String,dynamic>;
      final d = p['data'] as Map<String,dynamic>?;
      if (p['ok']!=true||d==null) { setState((){ _phpsessid=''; _log='Login gagal: ${p['error']}'; }); return; }
      final s = '${d['phpsessid']??''}';
      setState((){ _phpsessid=s; _log=s.isEmpty?'Login terproses tapi PHPSESSID kosong.':'Login sukses!'; });
      if (s.isNotEmpty) { await _fetchJadwal(); await _fetchPresensi(); }
    } on TimeoutException { setState(()=>_log='Timeout login (>30s).'); }
    catch(e) { setState(()=>_log='Error: $e'); }
    finally { setState(()=>_busyLogin=false); }
  }

  Future<void> _fetchJadwal() async {
    if (_phpsessid.isEmpty) return;
    setState(()=>_busyJadwal=true);
    try {
      final r = await http.post(Uri.parse('${_apiCtrl.text.trim()}/api/jadwal'),
        headers:{'Content-Type':'application/json'},
        body:jsonEncode({'base_url':_baseCtrl.text.trim(),'phpsessid':_phpsessid,
          'path':'/modul_siswa/jadwal_ujian_siswa/jadwal_ujian_siswa_view.php',
          'referer_path':'/modul_siswa/jadwal_ujian_siswa/jadwal_ujian_siswa.php?jenis=MHS&param_menu=&ujian=0&ekstra=0',
          'siswa_program_id':232}),
      ).timeout(const Duration(seconds:30));
      final p = jsonDecode(r.body) as Map<String,dynamic>;
      final d = p['data'] as Map<String,dynamic>?;
      if (p['ok']!=true||d==null) { setState(()=>_log='Jadwal gagal: ${p['error']}'); return; }
      final items = (d['items'] as List? ?? []).whereType<Map<String,dynamic>>().map(JadwalItem.fromJson).toList();
      setState((){ _jadwalItems=items; _lastSync=DateTime.now(); _log='Jadwal dimuat (${items.length} item).'; });
    } catch(e) { setState(()=>_log='Error jadwal: $e'); }
    finally { setState(()=>_busyJadwal=false); }
  }

  Future<void> _fetchPresensi() async {
    if (_phpsessid.isEmpty) return;
    setState(()=>_busyPresensi=true);
    try {
      final r = await http.post(Uri.parse('${_apiCtrl.text.trim()}/api/presensi'),
        headers:{'Content-Type':'application/json'},
        body:jsonEncode({'base_url':_baseCtrl.text.trim(),'phpsessid':_phpsessid}),
      ).timeout(const Duration(seconds:30));
      final p = jsonDecode(r.body) as Map<String,dynamic>;
      final d = p['data'] as Map<String,dynamic>?;
      if (p['ok']!=true||d==null) { setState((){ _presensiCourses=[]; _presensiMsg='Gagal: ${p['error']}'; }); return; }
      final courses = (d['courses'] as List? ?? []).whereType<Map<String,dynamic>>().map(PresensiCourse.fromJson).toList();
      setState((){ _presensiCourses=courses; _presensiMsg='${d['message']??''}'; });
    } catch(e) { setState((){ _presensiCourses=[]; _presensiMsg='Error: $e'; }); }
    finally { setState(()=>_busyPresensi=false); }
  }

  Future<void> _submitAttend(PresensiCourse c) async {
    setState(()=>_busyAttend=true);
    try {
      final r = await http.post(Uri.parse('${_apiCtrl.text.trim()}/api/attend'),
        headers:{'Content-Type':'application/json'},
        body:jsonEncode({'base_url':_baseCtrl.text.trim(),'phpsessid':_phpsessid,
          'id_krs':c.idKrs,'yang_ke':c.yangKe,'id_jadwal':c.idJadwal,'nama_mk':c.namaMK,
          'perkuliahan':c.perkuliahan,'ket_perkuliahan':c.ketPerkuliahan,'hibrid':c.hibrid}),
      ).timeout(const Duration(seconds:30));
      final p = jsonDecode(r.body) as Map<String,dynamic>;
      final d = p['data'] as Map<String,dynamic>?;
      final ok = d?['success']==true;
      final msg = '${d?['message']??p['error']??'Unknown'}';
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:Text(msg), backgroundColor:ok?Colors.green.shade700:Colors.red.shade700,
          behavior:SnackBarBehavior.floating, shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
        ));
      }
      if(ok) await _fetchPresensi();
    } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Error: $e'))); }
    finally { setState(()=>_busyAttend=false); }
  }

  void _logout() => setState((){ _phpsessid=''; _jadwalItems=[]; _presensiCourses=[]; _presensiMsg=''; _lastSync=null; _tabIndex=0; _log='Session dibersihkan.'; });

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFFE9F6FF),Color(0xFFF9FCF7)])),
        child: SafeArea(child: _loggedIn ? _dashboardLayout() : _loginLayout()),
      ),
      bottomNavigationBar: _loggedIn ? NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i)=>setState(()=>_tabIndex=i),
        destinations: const [
          NavigationDestination(icon:Icon(Icons.calendar_month_outlined),selectedIcon:Icon(Icons.calendar_month),label:'Jadwal'),
          NavigationDestination(icon:Icon(Icons.front_hand_outlined),selectedIcon:Icon(Icons.front_hand),label:'Presensi'),
        ],
      ) : null,
    );
  }

  // ── Login ──

  Widget _loginLayout() {
    return SingleChildScrollView(padding:const EdgeInsets.all(24), child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth:480),
      child: Column(children: [
        const SizedBox(height:40),
        Text('SWAAP', style:GoogleFonts.sora(fontSize:42,fontWeight:FontWeight.w800,color:const Color(0xFF0D78B7))),
        const SizedBox(height:4),
        const Text('Smart Wrapper Academic Portal', style:TextStyle(color:Color(0xFF5A7383),fontSize:14)),
        const SizedBox(height:36),
        _card(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Text('Login Akademik',style:GoogleFonts.sora(fontSize:22,fontWeight:FontWeight.w700,color:const Color(0xFF0F4F7B))),
          const SizedBox(height:16),
          _field(_userCtrl,'Username',Icons.badge_outlined,hint:'STI202303534'),
          _field(_passCtrl,'Password',Icons.lock_outline,obscure:true),
          _field(_macCtrl,'MAC Address (opsional)',Icons.memory),
          const SizedBox(height:12),
          SizedBox(width:double.infinity, child:FilledButton.icon(
            onPressed:_busy?null:_login, icon:const Icon(Icons.login_rounded),
            label:Padding(padding:const EdgeInsets.symmetric(vertical:14),child:Text(_busyLogin?'Memproses...':'Login Dan Muat Data')),
          )),
          if(_log.isNotEmpty) ...[const SizedBox(height:12), _logBox(_log)],
        ])),
      ]),
    )));
  }

  // ── Dashboard ──

  Widget _dashboardLayout() {
    return Column(children:[
      _header(),
      Expanded(child: IndexedStack(index:_tabIndex, children:[_jadwalTab(), _presensiTab()])),
    ]);
  }

  Widget _header() {
    final sid = _phpsessid.length>12 ? '${_phpsessid.substring(0,8)}...${_phpsessid.substring(_phpsessid.length-4)}' : _phpsessid;
    return Container(
      padding:const EdgeInsets.fromLTRB(20,16,20,12),
      decoration: const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF0E74B2),Color(0xFF1E9EDC)]),
        borderRadius:BorderRadius.only(bottomLeft:Radius.circular(28),bottomRight:Radius.circular(28)),
        boxShadow:[BoxShadow(color:Color(0x1F1A4A66),blurRadius:24,offset:Offset(0,14))]),
      child: Row(children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Text('SWAAP',style:GoogleFonts.sora(color:Colors.white,fontSize:22,fontWeight:FontWeight.w700)),
          const SizedBox(height:2),
          Text('Session: $sid', style:const TextStyle(color:Color(0xFFD4EDFA),fontSize:12)),
        ])),
        if(_busy) const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)),
        const SizedBox(width:8),
        IconButton(icon:const Icon(Icons.logout,color:Colors.white),onPressed:_busy?null:_logout,tooltip:'Logout'),
      ]),
    );
  }

  // ── Jadwal Tab ──

  Widget _jadwalTab() {
    final items = _filtered;
    return RefreshIndicator(
      onRefresh: _fetchJadwal,
      child: ListView(padding:const EdgeInsets.all(16), children:[
        Row(children:[
          Text('Jadwal Kuliah',style:GoogleFonts.sora(fontSize:20,fontWeight:FontWeight.w700,color:const Color(0xFF0F4F7B))),
          const Spacer(),
          if(_lastSync!=null) Text('${_lastSync!.hour.toString().padLeft(2,'0')}:${_lastSync!.minute.toString().padLeft(2,'0')}',style:const TextStyle(color:Color(0xFF627C8A),fontSize:12,fontWeight:FontWeight.w600)),
        ]),
        const SizedBox(height:4),
        const Text('Menampilkan jadwal aktif & akan datang (1 per matkul)',style:TextStyle(color:Color(0xFF5A7383),fontSize:12)),
        const SizedBox(height:16),
        if(items.isEmpty) _emptyState(Icons.calendar_today_outlined,'Tidak ada jadwal aktif saat ini.','Semua pertemuan sudah lewat atau belum ada data.'),
        ...items.map(_jadwalCard),
      ]),
    );
  }

  Widget _jadwalCard(JadwalItem item) {
    final ongoing = item.isOngoing;
    final upcoming = item.isUpcoming;
    final color = ongoing?const Color(0xFF2E7D32):upcoming?const Color(0xFF1976D2):const Color(0xFF5A7383);
    final label = ongoing?'Sedang Berlangsung':upcoming?'Akan Datang':'Selesai';

    return Container(
      margin:const EdgeInsets.only(bottom:14),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),
        boxShadow:[BoxShadow(color:color.withOpacity(0.08),blurRadius:16,offset:const Offset(0,8))]),
      clipBehavior:Clip.antiAlias,
      child:IntrinsicHeight(child:Row(children:[
        Container(width:5,color:color),
        Expanded(child:Padding(padding:const EdgeInsets.all(16), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Row(children:[
            Expanded(child:Text(item.courseName,style:GoogleFonts.sora(fontSize:16,fontWeight:FontWeight.w800,color:const Color(0xFF0F4F7B)))),
            _pill(item.method, item.method.toLowerCase().contains('daring')?const Color(0xFFE65100):const Color(0xFF2E7D32)),
          ]),
          const SizedBox(height:4),
          Text(item.lecturer,style:TextStyle(color:Colors.blueGrey.shade600,fontWeight:FontWeight.w500,fontSize:13)),
          const SizedBox(height:12),
          Wrap(spacing:12,runSpacing:6,children:[
            _iconLabel(Icons.meeting_room_outlined,item.room),
            _iconLabel(Icons.event_outlined,item.date),
            _iconLabel(Icons.schedule_outlined,item.time.replaceAll(' WIB','')),
          ]),
          const SizedBox(height:10),
          Row(children:[
            _pill(label, color),
            const Spacer(),
            Text('Pertemuan ${item.meeting}',style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:Colors.blueGrey)),
          ]),
        ]))),
      ])),
    );
  }

  // ── Presensi Tab ──

  Widget _presensiTab() {
    return RefreshIndicator(
      onRefresh: _fetchPresensi,
      child: ListView(padding:const EdgeInsets.all(16), children:[
        Row(children:[
          Text('Presensi Kehadiran',style:GoogleFonts.sora(fontSize:20,fontWeight:FontWeight.w700,color:const Color(0xFF0F4F7B))),
          const Spacer(),
          IconButton(icon:const Icon(Icons.refresh),onPressed:_busyPresensi?null:_fetchPresensi),
        ]),
        const SizedBox(height:4),
        const Text('Mata kuliah yang aktif saat ini (sesuai jam & tanggal)',style:TextStyle(color:Color(0xFF5A7383),fontSize:12)),
        const SizedBox(height:16),
        if(_busyPresensi) const Center(child:Padding(padding:EdgeInsets.all(32),child:CircularProgressIndicator())),
        if(!_busyPresensi && _presensiCourses.isEmpty)
          _emptyState(Icons.front_hand_outlined, _presensiMsg.isNotEmpty?_presensiMsg:'Tidak ada mata kuliah aktif.','Presensi hanya tersedia saat jam kuliah berlangsung.'),
        ..._presensiCourses.map(_presensiCard),
      ]),
    );
  }

  Widget _presensiCard(PresensiCourse c) {
    return Container(
      margin:const EdgeInsets.only(bottom:14),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),
        boxShadow:[BoxShadow(color:Colors.green.withOpacity(0.08),blurRadius:16,offset:const Offset(0,8))]),
      clipBehavior:Clip.antiAlias,
      child:IntrinsicHeight(child:Row(children:[
        Container(width:5,color:const Color(0xFF2E7D32)),
        Expanded(child:Padding(padding:const EdgeInsets.all(16), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Text(c.namaMK,style:GoogleFonts.sora(fontSize:16,fontWeight:FontWeight.w800,color:const Color(0xFF0F4F7B))),
          const SizedBox(height:4),
          Text('Pertemuan ke-${c.yangKe}',style:TextStyle(color:Colors.blueGrey.shade600,fontSize:13)),
          if(c.ketPerkuliahan.isNotEmpty) ...[const SizedBox(height:2), _pill(c.ketPerkuliahan, const Color(0xFF2E7D32))],
          const SizedBox(height:14),
          SizedBox(width:double.infinity, child:FilledButton.icon(
            onPressed:_busyAttend?null:()=>_confirmAttend(c),
            icon:const Icon(Icons.front_hand),
            label:Text(_busyAttend?'Memproses...':'Hadir'),
            style:FilledButton.styleFrom(backgroundColor:const Color(0xFF2E7D32),padding:const EdgeInsets.symmetric(vertical:14),
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
          )),
        ]))),
      ])),
    );
  }

  void _confirmAttend(PresensiCourse c) {
    showDialog(context:context, builder:(ctx)=>AlertDialog(
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
      title:const Text('Konfirmasi Presensi'),
      content:Text('Yakin ingin presensi hadir untuk:\n\n${c.namaMK}\nPertemuan ke-${c.yangKe}?'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Batal')),
        FilledButton(onPressed:(){ Navigator.pop(ctx); _submitAttend(c); },child:const Text('Ya, Hadir')),
      ],
    ));
  }

  // ── Shared Widgets ──

  Widget _card({required Widget child}) => Container(
    padding:const EdgeInsets.all(22),
    decoration:BoxDecoration(color:const Color(0xF7FFFFFF),borderRadius:BorderRadius.circular(24),
      border:Border.all(color:const Color(0xFFD4EAF5)),
      boxShadow:const [BoxShadow(color:Color(0x140B3650),blurRadius:22,offset:Offset(0,8))]),
    child:child,
  );

  Widget _field(TextEditingController c, String label, IconData icon, {String? hint, bool obscure=false}) => Padding(
    padding:const EdgeInsets.only(bottom:10),
    child:TextField(controller:c,obscureText:obscure,decoration:InputDecoration(labelText:label,hintText:hint,prefixIcon:Icon(icon),
      border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))),
  );

  Widget _logBox(String text) => Container(
    width:double.infinity, padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:const Color(0xFFF8FCFF),borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFFCFE4EF))),
    child:Text(text,style:const TextStyle(height:1.4)),
  );

  Widget _pill(String label, Color color) => Container(
    padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
    decoration:BoxDecoration(color:color.withOpacity(0.1),borderRadius:BorderRadius.circular(8),border:Border.all(color:color.withOpacity(0.2))),
    child:Text(label,style:TextStyle(color:color,fontSize:11,fontWeight:FontWeight.bold)),
  );

  Widget _iconLabel(IconData icon, String label) => Row(mainAxisSize:MainAxisSize.min, children:[
    Icon(icon,size:15,color:Colors.blueGrey.shade400), const SizedBox(width:4),
    Text(label,style:TextStyle(fontSize:12,color:Colors.blueGrey.shade700,fontWeight:FontWeight.w600)),
  ]);

  Widget _emptyState(IconData icon, String title, String sub) => Container(
    width:double.infinity, padding:const EdgeInsets.all(32),
    decoration:BoxDecoration(color:Colors.white.withOpacity(0.6),borderRadius:BorderRadius.circular(24)),
    child:Column(children:[
      Icon(icon,size:48,color:Colors.blueGrey.withOpacity(0.4)),
      const SizedBox(height:12),
      Text(title,textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.w600,color:Colors.blueGrey.shade600)),
      const SizedBox(height:4),
      Text(sub,textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:Colors.blueGrey.shade400)),
    ]),
  );
}
