import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/aspirasi_model.dart';

/// Service for Aspirasi/Aduan API calls.
class AspirasiService {
  final String apiBase;

  const AspirasiService({required this.apiBase});

  /// Submit a new aspirasi/aduan.
  Future<Map<String, dynamic>> submit({
    required String nim,
    required String nama,
    required String sasaran,
    required String kritik,
    required String saran,
    required bool isAnonim,
    String semester = '',
    String jurusan = '',
  }) async {
    final r = await http.post(
      Uri.parse('$apiBase/api/aspirasi/submit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nim': nim,
        'nama': nama,
        'sasaran': sasaran,
        'kritik': kritik,
        'saran': saran,
        'is_anonim': isAnonim,
        'semester': semester,
        'jurusan': jurusan,
      }),
    ).timeout(const Duration(seconds: 15));

    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Fetch public aspirasi list.
  Future<List<Aspirasi>> fetchList({int page = 1}) async {
    final r = await http.get(
      Uri.parse('$apiBase/api/aspirasi/list?page=$page'),
    ).timeout(const Duration(seconds: 15));

    final p = jsonDecode(r.body) as Map<String, dynamic>;
    if (p['ok'] != true) return [];

    final data = p['data'] as Map<String, dynamic>? ?? {};
    final items = (data['items'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Aspirasi.fromJson)
        .toList();
    return items;
  }

  /// Fetch current user's aspirasi.
  Future<List<Aspirasi>> fetchMy({required String nim}) async {
    final r = await http.post(
      Uri.parse('$apiBase/api/aspirasi/my'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nim': nim}),
    ).timeout(const Duration(seconds: 15));

    final p = jsonDecode(r.body) as Map<String, dynamic>;
    if (p['ok'] != true) return [];

    final data = p['data'] as Map<String, dynamic>? ?? {};
    final items = (data['items'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Aspirasi.fromJson)
        .toList();
    return items;
  }

  /// Fetch all aspirasi as admin (shows all identities).
  Future<List<Aspirasi>> fetchAdminList({required String nim, int page = 1}) async {
    final r = await http.post(
      Uri.parse('$apiBase/api/aspirasi/admin/list?page=$page'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nim': nim}),
    ).timeout(const Duration(seconds: 15));

    final p = jsonDecode(r.body) as Map<String, dynamic>;
    if (p['ok'] != true) return [];

    final data = p['data'] as Map<String, dynamic>? ?? {};
    final items = (data['items'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Aspirasi.fromJson)
        .toList();
    return items;
  }

  /// Check if NIM is admin.
  Future<bool> checkAdmin({required String nim}) async {
    try {
      final r = await http.post(
        Uri.parse('$apiBase/api/admin/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nim': nim}),
      ).timeout(const Duration(seconds: 10));

      final p = jsonDecode(r.body) as Map<String, dynamic>;
      if (p['ok'] != true) return false;
      final data = p['data'] as Map<String, dynamic>? ?? {};
      return data['is_admin'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Delete user's own aspirasi (must be pending).
  Future<Map<String, dynamic>> deleteAspirasi({
    required String nim,
    required int aspirasiId,
  }) async {
    final r = await http.post(
      Uri.parse('$apiBase/api/aspirasi/delete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nim': nim,
        'id': aspirasiId,
      }),
    ).timeout(const Duration(seconds: 15));

    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Update aspirasi status and admin reply (admin only).
  Future<Map<String, dynamic>> updateStatus({
    required String nim,
    required int aspirasiId,
    required String status,
    required String adminReply,
  }) async {
    final r = await http.post(
      Uri.parse('$apiBase/api/aspirasi/admin/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nim': nim,
        'id': aspirasiId,
        'status': status,
        'admin_reply': adminReply,
      }),
    ).timeout(const Duration(seconds: 15));

    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Add new admin (only existing admin can do this).
  Future<Map<String, dynamic>> addAdmin({
    required String adminNim,
    required String newNim,
    String newNama = '',
  }) async {
    final r = await http.post(
      Uri.parse('$apiBase/api/admin/add'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'admin_nim': adminNim,
        'new_nim': newNim,
        'new_nama': newNama,
      }),
    ).timeout(const Duration(seconds: 10));

    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
