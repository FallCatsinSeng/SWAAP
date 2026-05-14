import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Zoom link parser — handles both URL and plain text formats
class ZoomInfo {
  final String meetingId, password, roomOnly;
  const ZoomInfo({required this.meetingId, required this.password, required this.roomOnly});
  bool get hasZoom => meetingId.isNotEmpty;
  static ZoomInfo parse(String room) {
    final idx = room.toLowerCase().indexOf('link zoom');
    if (idx < 0) return ZoomInfo(meetingId:'',password:'',roomOnly:room.trim());
    final roomOnly = room.substring(0, idx).trim();
    // Get everything after "Link Zoom" and strip the colon/spaces
    var rest = room.substring(idx);
    rest = rest.replaceFirst(RegExp(r'[Ll]ink\s*[Zz]oom\s*:?\s*'), '').trim();
    // Try URL format first: https://zoom.us/j/123?pwd=abc
    final urlMatch = RegExp(r'https?://\S+').firstMatch(rest);
    if (urlMatch != null) {
      final uri = Uri.tryParse(urlMatch.group(0)!);
      if (uri != null) {
        String mid = '';
        final jIdx = uri.path.indexOf('/j/');
        if (jIdx >= 0) mid = uri.path.substring(jIdx + 3).replaceAll('/', '');
        return ZoomInfo(meetingId:mid, password:uri.queryParameters['pwd']??'', roomOnly:roomOnly);
      }
    }
    // Plain text format: "687 529 1614 swu12345" or "6875291614 swu12345"
    final nums = RegExp(r'[\d\s]+').firstMatch(rest)?.group(0)?.trim() ?? '';
    final afterNums = rest.substring(nums.length).trim();
    return ZoomInfo(meetingId:nums, password:afterNums, roomOnly:roomOnly);
  }
}

void main() => runApp(const SwaapApp());

String _apiBase() {
  if (kIsWeb) return 'http://localhost:8081';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8081';
  return 'http://127.0.0.1:8081';
}

class JadwalItem {
  final int rowId;
  final String meeting, date, time, room, method, courseName, lecturer;
  const JadwalItem({required this.rowId, required this.meeting, required this.date, required this.time, required this.room, required this.method, required this.courseName, required this.lecturer});
  DateTime? get startDT { try { final d=date.split('-'); final t=time.split('-')[0].trim().replaceAll('.',':').split(':'); return DateTime(int.parse(d[2]),int.parse(d[1]),int.parse(d[0]),int.parse(t[0]),int.parse(t[1])); } catch(_){return null;} }
  DateTime? get endDT { try { final d=date.split('-'); final t=time.split('-')[1].trim().split(' ')[0].replaceAll('.',':').split(':'); return DateTime(int.parse(d[2]),int.parse(d[1]),int.parse(d[0]),int.parse(t[0]),int.parse(t[1])); } catch(_){return null;} }
  bool get isOngoing { final n=DateTime.now(),s=startDT,e=endDT; return s!=null&&e!=null&&n.isAfter(s)&&n.isBefore(e); }
  bool get isUpcoming { final s=startDT; return s!=null&&DateTime.now().isBefore(s); }
  factory JadwalItem.fromJson(Map<String,dynamic> j) => JadwalItem(rowId:(j['row_id']??0)as int,meeting:'${j['meeting']??''}',date:'${j['date']??''}',time:'${j['time']??''}',room:'${j['room']??''}',method:'${j['method']??''}',courseName:'${j['course_name']??''}',lecturer:'${j['lecturer']??''}');
}

class PresensiCourse {
  final int idKrs, yangKe, idJadwal, hibrid;
  final String namaMK, perkuliahan, ketPerkuliahan;
  const PresensiCourse({required this.idKrs, required this.yangKe, required this.idJadwal, required this.hibrid, required this.namaMK, required this.perkuliahan, required this.ketPerkuliahan});
  factory PresensiCourse.fromJson(Map<String,dynamic> j) => PresensiCourse(idKrs:(j['id_krs']??0)as int,yangKe:(j['yang_ke']??0)as int,idJadwal:(j['id_jadwal']??0)as int,hibrid:(j['hibrid']??0)as int,namaMK:'${j['nama_mk']??''}',perkuliahan:'${j['perkuliahan']??''}',ketPerkuliahan:'${j['ket_perkuliahan']??''}');
}

// ── Credential Storage ──
class CredStore {
  static const _kUser='swaap_user', _kPass='swaap_pass', _kBase='swaap_base', _kMac='swaap_mac', _kApi='swaap_api';
  static Future<void> save({required String user, required String pass, required String base, required String mac, required String api}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUser, user); await p.setString(_kPass, pass);
    await p.setString(_kBase, base); await p.setString(_kMac, mac); await p.setString(_kApi, api);
  }
  static Future<Map<String,String>?> load() async {
    final p = await SharedPreferences.getInstance();
    final u=p.getString(_kUser), pw=p.getString(_kPass);
    if (u==null||u.isEmpty||pw==null||pw.isEmpty) return null;
    return {'user':u,'pass':pw,'base':p.getString(_kBase)??'','mac':p.getString(_kMac)??'','api':p.getString(_kApi)??''};
  }
  static Future<void> clear() async { final p=await SharedPreferences.getInstance(); await p.clear(); }
}

class SwaapApp extends StatelessWidget {
  const SwaapApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'SWAAP',
    theme:ThemeData(useMaterial3:true,textTheme:GoogleFonts.plusJakartaSansTextTheme(),colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF0D78B7))),
    home:const MainPage());
}

class MainPage extends StatefulWidget { const MainPage({super.key}); @override State<MainPage> createState()=>_MainPageState(); }

class _MainPageState extends State<MainPage> {
  final _apiCtrl=TextEditingController(text:_apiBase());
  final _baseCtrl=TextEditingController(text:'https://smartone.smart-service.co.id');
  final _userCtrl=TextEditingController(), _passCtrl=TextEditingController();
  final _jadwalScroll=ScrollController(), _presensiScroll=ScrollController();
  String _phpsessid='', _log='Memuat...';
  bool _busyLogin=false, _busyJadwal=false, _busyPresensi=false, _busyAttend=false, _initDone=false;
  int _tabIndex=0;
  DateTime? _lastSync;
  List<JadwalItem> _jadwalItems=[];
  List<PresensiCourse> _presensiCourses=[];
  String _presensiMsg='';

  bool get _loggedIn=>_phpsessid.isNotEmpty;
  bool get _busy=>_busyLogin||_busyJadwal||_busyPresensi||_busyAttend;

  List<JadwalItem> get _filtered {
    final now=DateTime.now();
    final ongoing=_jadwalItems.where((i)=>i.isOngoing).toList();
    final upMap=<String,JadwalItem>{};
    for(final i in _jadwalItems.where((i)=>i.isUpcoming)){final ex=upMap[i.courseName];if(ex==null||(i.startDT!=null&&ex.startDT!=null&&i.startDT!.isBefore(ex.startDT!)))upMap[i.courseName]=i;}
    final up=upMap.values.toList()..sort((a,b)=>(a.startDT??now).compareTo(b.startDT??now));
    return [...ongoing,...up];
  }

  // Find zoom info for a course by scanning ALL meetings (newest first)
  ZoomInfo _zoomForCourse(String courseName) {
    final all = _jadwalItems.where((i)=>i.courseName==courseName).toList();
    // Sort descending by meeting number to prefer latest
    all.sort((a,b)=>int.tryParse(b.meeting)?.compareTo(int.tryParse(a.meeting)??0)??0);
    for (final item in all) {
      final z = ZoomInfo.parse(item.room);
      if (z.hasZoom) return z;
    }
    return ZoomInfo(meetingId:'',password:'',roomOnly:'');
  }

  @override void initState() { super.initState(); _tryAutoLogin(); }
  @override void dispose() { _apiCtrl.dispose();_baseCtrl.dispose();_userCtrl.dispose();_passCtrl.dispose();_jadwalScroll.dispose();_presensiScroll.dispose(); super.dispose(); }

  Future<void> _tryAutoLogin() async {
    final creds = await CredStore.load();
    if (creds!=null) {
      _userCtrl.text=creds['user']!; _passCtrl.text=creds['pass']!;
      if(creds['base']!.isNotEmpty) _baseCtrl.text=creds['base']!;
      if(creds['api']!.isNotEmpty) _apiCtrl.text=creds['api']!;
      setState((){ _initDone=true; _log='Auto login dengan kredensial tersimpan...'; });
      await _doLogin(silent:true);
    } else {
      setState((){ _initDone=true; _log='Siap login.'; });
    }
  }

  Future<void> _reLogin() async {
    final creds=await CredStore.load();
    if(creds==null) { _logout(); return; }
    _userCtrl.text=creds['user']!; _passCtrl.text=creds['pass']!;
    await _doLogin(silent:true);
  }

  Future<void> _login() async => _doLogin(silent:false);

  Future<void> _doLogin({bool silent=false}) async {
    if(_userCtrl.text.trim().isEmpty||_passCtrl.text.trim().isEmpty){setState(()=>_log='Username dan password wajib diisi.');return;}
    setState((){_busyLogin=true; if(!silent) _log='Mengirim login...';});
    try{
      final r=await http.post(Uri.parse('${_apiCtrl.text.trim()}/api/login'),headers:{'Content-Type':'application/json'},
        body:jsonEncode({'base_url':_baseCtrl.text.trim(),'username':_userCtrl.text.trim(),'password':_passCtrl.text,'mac_addr':'',
          'accept_language':'en-US,en;q=0.9','user_agent':'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36'}),
      ).timeout(const Duration(seconds:30));
      final p=jsonDecode(r.body) as Map<String,dynamic>;
      final d=p['data'] as Map<String,dynamic>?;
      if(p['ok']!=true||d==null){setState((){_phpsessid='';_log='Login gagal: ${p['error']}';});return;}
      final s='${d['phpsessid']??''}';
      setState((){_phpsessid=s;_log=s.isEmpty?'PHPSESSID kosong.':'Login sukses!';});
      if(s.isNotEmpty){
        await CredStore.save(user:_userCtrl.text.trim(),pass:_passCtrl.text,base:_baseCtrl.text.trim(),mac:'',api:_apiCtrl.text.trim());
        await _fetchJadwal(); await _fetchPresensi();
      }
    } on TimeoutException{setState(()=>_log='Timeout login.');}
    catch(e){setState(()=>_log='Error: $e');}
    finally{setState(()=>_busyLogin=false);}
  }

  Future<T?> _withReLogin<T>(Future<T?> Function() fn) async {
    try { return await fn(); } catch(e) {
      if(e.toString().contains('502')||e.toString().contains('session')) { await _reLogin(); if(_loggedIn) return await fn(); }
      rethrow;
    }
  }

  Future<void> _fetchJadwal() async {
    if(_phpsessid.isEmpty)return; setState(()=>_busyJadwal=true);
    try{
      final r=await http.post(Uri.parse('${_apiCtrl.text.trim()}/api/jadwal'),headers:{'Content-Type':'application/json'},
        body:jsonEncode({'base_url':_baseCtrl.text.trim(),'phpsessid':_phpsessid,'path':'/modul_siswa/jadwal_ujian_siswa/jadwal_ujian_siswa_view.php',
          'referer_path':'/modul_siswa/jadwal_ujian_siswa/jadwal_ujian_siswa.php?jenis=MHS&param_menu=&ujian=0&ekstra=0','siswa_program_id':232}),
      ).timeout(const Duration(seconds:30));
      final p=jsonDecode(r.body) as Map<String,dynamic>;
      if(p['ok']!=true){
        if(r.statusCode==502){await _reLogin();if(_loggedIn)return _fetchJadwal();}
        setState(()=>_log='Jadwal gagal: ${p['error']}'); return;
      }
      final d=p['data'] as Map<String,dynamic>?;if(d==null)return;
      final items=(d['items']as List?? []).whereType<Map<String,dynamic>>().map(JadwalItem.fromJson).toList();
      setState((){_jadwalItems=items;_lastSync=DateTime.now();_log='Jadwal dimuat (${items.length} item).';});
    }catch(e){setState(()=>_log='Error jadwal: $e');}
    finally{setState(()=>_busyJadwal=false);}
  }

  Future<void> _fetchPresensi() async {
    if(_phpsessid.isEmpty)return; setState(()=>_busyPresensi=true);
    try{
      final r=await http.post(Uri.parse('${_apiCtrl.text.trim()}/api/presensi'),headers:{'Content-Type':'application/json'},
        body:jsonEncode({'base_url':_baseCtrl.text.trim(),'phpsessid':_phpsessid}),
      ).timeout(const Duration(seconds:30));
      final p=jsonDecode(r.body) as Map<String,dynamic>;
      if(p['ok']!=true){setState((){_presensiCourses=[];_presensiMsg='Gagal: ${p['error']}';});return;}
      final d=p['data'] as Map<String,dynamic>?;if(d==null)return;
      final c=(d['courses']as List?? []).whereType<Map<String,dynamic>>().map(PresensiCourse.fromJson).toList();
      setState((){_presensiCourses=c;_presensiMsg='${d['message']??''}';});
    }catch(e){setState((){_presensiCourses=[];_presensiMsg='Error: $e';});}
    finally{setState(()=>_busyPresensi=false);}
  }

  Future<void> _submitAttend(PresensiCourse c) async {
    setState(()=>_busyAttend=true);
    try{
      final r=await http.post(Uri.parse('${_apiCtrl.text.trim()}/api/attend'),headers:{'Content-Type':'application/json'},
        body:jsonEncode({'base_url':_baseCtrl.text.trim(),'phpsessid':_phpsessid,'id_krs':c.idKrs,'yang_ke':c.yangKe,'id_jadwal':c.idJadwal,'nama_mk':c.namaMK,'perkuliahan':c.perkuliahan,'ket_perkuliahan':c.ketPerkuliahan,'hibrid':c.hibrid}),
      ).timeout(const Duration(seconds:30));
      final p=jsonDecode(r.body) as Map<String,dynamic>;final d=p['data'] as Map<String,dynamic>?;
      final ok=d?['success']==true; final msg='${d?['message']??p['error']??'Unknown'}';
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg),backgroundColor:ok?Colors.green.shade700:Colors.red.shade700,behavior:SnackBarBehavior.floating,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))));
      if(ok) await _fetchPresensi();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Error: $e')));}
    finally{setState(()=>_busyAttend=false);}
  }

  void _logout() async { await CredStore.clear(); setState((){_phpsessid='';_jadwalItems=[];_presensiCourses=[];_presensiMsg='';_lastSync=null;_tabIndex=0;_log='Session dibersihkan.';}); }

  @override Widget build(BuildContext context) {
    if(!_initDone) return const Scaffold(body:Center(child:CircularProgressIndicator()));
    return Scaffold(
      body:Container(decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFFE9F6FF),Color(0xFFF9FCF7)])),
        child:SafeArea(child:_loggedIn?_dashboard():_loginLayout())),
      bottomNavigationBar:_loggedIn?NavigationBar(selectedIndex:_tabIndex,onDestinationSelected:(i)=>setState(()=>_tabIndex=i),
        destinations:const[NavigationDestination(icon:Icon(Icons.calendar_month_outlined),selectedIcon:Icon(Icons.calendar_month),label:'Jadwal'),
          NavigationDestination(icon:Icon(Icons.front_hand_outlined),selectedIcon:Icon(Icons.front_hand),label:'Presensi')]):null,
    );
  }

  Widget _loginLayout() => SingleChildScrollView(padding:const EdgeInsets.all(24),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:480),
    child:Column(children:[
      const SizedBox(height:40),
      Text('SWAAP',style:GoogleFonts.sora(fontSize:42,fontWeight:FontWeight.w800,color:const Color(0xFF0D78B7))),
      const SizedBox(height:4), const Text('Smart Wrapper Academic Portal',style:TextStyle(color:Color(0xFF5A7383),fontSize:14)),
      const SizedBox(height:36),
      _card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Login Akademik',style:GoogleFonts.sora(fontSize:22,fontWeight:FontWeight.w700,color:const Color(0xFF0F4F7B))),
        const SizedBox(height:16),
        _field(_userCtrl,'Username',Icons.badge_outlined,hint:'STI202303534'),
        _field(_passCtrl,'Password',Icons.lock_outline,obscure:true),
        const SizedBox(height:12),
        SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_busy?null:_login,icon:const Icon(Icons.login_rounded),
          label:Padding(padding:const EdgeInsets.symmetric(vertical:14),child:Text(_busyLogin?'Memproses...':'Login')))),
        if(_log.isNotEmpty)...[const SizedBox(height:12),_logBox(_log)],
      ])),
    ]))));

  Widget _dashboard() => Column(children:[_header(),Expanded(child:IndexedStack(index:_tabIndex,children:[_jadwalTab(),_presensiTab()]))]);

  Widget _header() {
    final sid=_phpsessid.length>12?'${_phpsessid.substring(0,8)}...${_phpsessid.substring(_phpsessid.length-4)}':_phpsessid;
    return Container(padding:const EdgeInsets.fromLTRB(20,16,20,12),
      decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF0E74B2),Color(0xFF1E9EDC)]),
        borderRadius:BorderRadius.only(bottomLeft:Radius.circular(28),bottomRight:Radius.circular(28)),
        boxShadow:[BoxShadow(color:Color(0x1F1A4A66),blurRadius:24,offset:Offset(0,14))]),
      child:Row(children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('SWAAP',style:GoogleFonts.sora(color:Colors.white,fontSize:22,fontWeight:FontWeight.w700)),
          const SizedBox(height:2), Text('Session: $sid',style:const TextStyle(color:Color(0xFFD4EDFA),fontSize:12)),
        ])),
        if(_busy)const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)),
        const SizedBox(width:8),
        IconButton(icon:const Icon(Icons.logout,color:Colors.white),onPressed:_busy?null:_logout,tooltip:'Logout'),
      ]));
  }

  Widget _jadwalTab() {
    final items=_filtered;
    return RefreshIndicator(onRefresh:_fetchJadwal,child:ListView(controller:_jadwalScroll,padding:const EdgeInsets.all(16),children:[
      Row(children:[Text('Jadwal Kuliah',style:GoogleFonts.sora(fontSize:20,fontWeight:FontWeight.w700,color:const Color(0xFF0F4F7B))),const Spacer(),
        if(_lastSync!=null)Text('${_lastSync!.hour.toString().padLeft(2,'0')}:${_lastSync!.minute.toString().padLeft(2,'0')}',style:const TextStyle(color:Color(0xFF627C8A),fontSize:12,fontWeight:FontWeight.w600))]),
      const SizedBox(height:4),const Text('Jadwal aktif & akan datang (1 per matkul)',style:TextStyle(color:Color(0xFF5A7383),fontSize:12)),
      const SizedBox(height:16),
      if(items.isEmpty)_emptyState(Icons.calendar_today_outlined,'Tidak ada jadwal aktif.','Semua pertemuan sudah lewat.'),
      ...items.map(_jadwalCard),
    ]));
  }

  Widget _jadwalCard(JadwalItem item) {
    final color=item.isOngoing?const Color(0xFF2E7D32):item.isUpcoming?const Color(0xFF1976D2):const Color(0xFF5A7383);
    final label=item.isOngoing?'Sedang Berlangsung':item.isUpcoming?'Akan Datang':'Selesai';
    // Try current item's zoom first, then inherit from any meeting of same course
    var zoom = ZoomInfo.parse(item.room);
    if (!zoom.hasZoom) zoom = _zoomForCourse(item.courseName);
    return Container(margin:const EdgeInsets.only(bottom:14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),
      boxShadow:[BoxShadow(color:color.withOpacity(0.08),blurRadius:16,offset:const Offset(0,8))]),clipBehavior:Clip.antiAlias,
      child:IntrinsicHeight(child:Row(children:[Container(width:5,color:color),
        Expanded(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text(item.courseName,style:GoogleFonts.sora(fontSize:16,fontWeight:FontWeight.w800,color:const Color(0xFF0F4F7B)))),
            _pill(item.method,item.method.toLowerCase().contains('daring')?const Color(0xFFE65100):const Color(0xFF2E7D32))]),
          const SizedBox(height:4),Text(item.lecturer,style:TextStyle(color:Colors.blueGrey.shade600,fontWeight:FontWeight.w500,fontSize:13)),
          const SizedBox(height:12),
          Wrap(spacing:12,runSpacing:6,children:[_iconLabel(Icons.meeting_room_outlined,zoom.roomOnly.isNotEmpty?zoom.roomOnly:'-'),_iconLabel(Icons.event_outlined,item.date),_iconLabel(Icons.schedule_outlined,item.time.replaceAll(' WIB',''))]),
          if(zoom.hasZoom)...[const SizedBox(height:12),_zoomSection(zoom)],
          const SizedBox(height:10),Row(children:[_pill(label,color),const Spacer(),Text('Pertemuan ${item.meeting}',style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:Colors.blueGrey))]),
        ])))])));
  }

  Widget _presensiTab() => RefreshIndicator(onRefresh:_fetchPresensi,child:ListView(controller:_presensiScroll,padding:const EdgeInsets.all(16),children:[
    Row(children:[Text('Presensi',style:GoogleFonts.sora(fontSize:20,fontWeight:FontWeight.w700,color:const Color(0xFF0F4F7B))),const Spacer(),
      IconButton(icon:const Icon(Icons.refresh),onPressed:_busyPresensi?null:_fetchPresensi)]),
    const SizedBox(height:4),const Text('Mata kuliah aktif saat ini',style:TextStyle(color:Color(0xFF5A7383),fontSize:12)),
    const SizedBox(height:16),
    if(_busyPresensi)const Center(child:Padding(padding:EdgeInsets.all(32),child:CircularProgressIndicator())),
    if(!_busyPresensi&&_presensiCourses.isEmpty)_emptyState(Icons.front_hand_outlined,_presensiMsg.isNotEmpty?_presensiMsg:'Tidak ada matkul aktif.','Presensi tersedia saat jam kuliah.'),
    ..._presensiCourses.map(_presensiCard),
  ]));

  Widget _presensiCard(PresensiCourse c) => Container(margin:const EdgeInsets.only(bottom:14),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),boxShadow:[BoxShadow(color:Colors.green.withOpacity(0.08),blurRadius:16,offset:const Offset(0,8))]),
    clipBehavior:Clip.antiAlias,child:IntrinsicHeight(child:Row(children:[Container(width:5,color:const Color(0xFF2E7D32)),
      Expanded(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(c.namaMK,style:GoogleFonts.sora(fontSize:16,fontWeight:FontWeight.w800,color:const Color(0xFF0F4F7B))),
        const SizedBox(height:4),Text('Pertemuan ke-${c.yangKe}',style:TextStyle(color:Colors.blueGrey.shade600,fontSize:13)),
        if(c.ketPerkuliahan.isNotEmpty)...[const SizedBox(height:2),_pill(c.ketPerkuliahan,const Color(0xFF2E7D32))],
        const SizedBox(height:14),
        SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_busyAttend?null:()=>_confirmAttend(c),icon:const Icon(Icons.front_hand),
          label:Text(_busyAttend?'Memproses...':'Hadir'),style:FilledButton.styleFrom(backgroundColor:const Color(0xFF2E7D32),padding:const EdgeInsets.symmetric(vertical:14),
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))))),
      ])))])));

  void _confirmAttend(PresensiCourse c) => showDialog(context:context,builder:(ctx)=>AlertDialog(
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),title:const Text('Konfirmasi Presensi'),
    content:Text('Presensi hadir untuk:\n\n${c.namaMK}\nPertemuan ke-${c.yangKe}?'),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Batal')),
      FilledButton(onPressed:(){Navigator.pop(ctx);_submitAttend(c);},child:const Text('Ya, Hadir'))]));

  Widget _zoomSection(ZoomInfo z) {
    return Container(
      padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(color:const Color(0xFFF0F7FF),borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFFD0E4F5))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Icon(Icons.videocam,size:16,color:Colors.blue.shade700),const SizedBox(width:6),
          Text('Zoom Meeting',style:TextStyle(fontWeight:FontWeight.w700,fontSize:13,color:Colors.blue.shade700))]),
        const SizedBox(height:8),
        if(z.meetingId.isNotEmpty) _copyRow('Meeting ID', z.meetingId),
        if(z.password.isNotEmpty) ...[const SizedBox(height:6), _copyRow('Password', z.password)],
      ]),
    );
  }

  Widget _copyRow(String label, String value) {
    return Row(children:[
      Text('$label: ',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:Color(0xFF3A6B8C))),
      Expanded(child:Text(value,style:const TextStyle(fontSize:12,fontFamily:'monospace',color:Color(0xFF1A4A6B)))),
      InkWell(
        onTap:(){Clipboard.setData(ClipboardData(text:value));if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$label disalin'),duration:const Duration(seconds:1),behavior:SnackBarBehavior.floating));},
        borderRadius:BorderRadius.circular(8),
        child:Container(padding:const EdgeInsets.all(6),decoration:BoxDecoration(color:Colors.blue.shade50,borderRadius:BorderRadius.circular(8)),
          child:Icon(Icons.copy,size:14,color:Colors.blue.shade700)),
      ),
    ]);
  }

  Widget _card({required Widget child})=>Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:const Color(0xF7FFFFFF),borderRadius:BorderRadius.circular(24),border:Border.all(color:const Color(0xFFD4EAF5)),boxShadow:const[BoxShadow(color:Color(0x140B3650),blurRadius:22,offset:Offset(0,8))]),child:child);
  Widget _field(TextEditingController c,String l,IconData i,{String? hint,bool obscure=false})=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:c,obscureText:obscure,decoration:InputDecoration(labelText:l,hintText:hint,prefixIcon:Icon(i),border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))));
  Widget _logBox(String t)=>Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFFF8FCFF),borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFFCFE4EF))),child:Text(t,style:const TextStyle(height:1.4)));
  Widget _pill(String l,Color c)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),decoration:BoxDecoration(color:c.withOpacity(0.1),borderRadius:BorderRadius.circular(8),border:Border.all(color:c.withOpacity(0.2))),child:Text(l,style:TextStyle(color:c,fontSize:11,fontWeight:FontWeight.bold)));
  Widget _iconLabel(IconData i,String l)=>Row(mainAxisSize:MainAxisSize.min,children:[Icon(i,size:15,color:Colors.blueGrey.shade400),const SizedBox(width:4),Text(l,style:TextStyle(fontSize:12,color:Colors.blueGrey.shade700,fontWeight:FontWeight.w600))]);
  Widget _emptyState(IconData i,String t,String s)=>Container(width:double.infinity,padding:const EdgeInsets.all(32),decoration:BoxDecoration(color:Colors.white.withOpacity(0.6),borderRadius:BorderRadius.circular(24)),child:Column(children:[Icon(i,size:48,color:Colors.blueGrey.withOpacity(0.4)),const SizedBox(height:12),Text(t,textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.w600,color:Colors.blueGrey.shade600)),const SizedBox(height:4),Text(s,textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:Colors.blueGrey.shade400))]));
}
