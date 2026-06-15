/// Model for Aspirasi/Aduan items from the API.
class Aspirasi {
  final int id;
  final String nim;
  final String nama;
  final String semester;
  final String jurusan;
  final String sasaran;
  final String kritik;
  final String saran;
  final bool isAnonim;
  final String status;
  final String adminReply;
  final DateTime createdAt;

  const Aspirasi({
    required this.id,
    required this.nim,
    required this.nama,
    required this.semester,
    required this.jurusan,
    required this.sasaran,
    required this.kritik,
    required this.saran,
    required this.isAnonim,
    required this.status,
    required this.adminReply,
    required this.createdAt,
  });

  factory Aspirasi.fromJson(Map<String, dynamic> json) {
    return Aspirasi(
      id: json['id'] as int? ?? 0,
      nim: '${json['nim'] ?? ''}',
      nama: '${json['nama'] ?? ''}',
      semester: '${json['semester'] ?? ''}',
      jurusan: '${json['jurusan'] ?? ''}',
      sasaran: '${json['sasaran'] ?? ''}',
      kritik: '${json['kritik'] ?? ''}',
      saran: '${json['saran'] ?? ''}',
      isAnonim: json['is_anonim'] == true,
      status: '${json['status'] ?? 'pending'}',
      adminReply: '${json['admin_reply'] ?? ''}',
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
    );
  }

  /// Status display label
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'diproses':
        return 'Diproses';
      case 'selesai':
        return 'Selesai';
      default:
        return status;
    }
  }

  /// Display name — shows "Anonim" if anonymous
  String get displayName => isAnonim ? 'Anonim' : nama;

  /// Display info — shows semester + jurusan for anonim, nim for non-anonim
  String get displayInfo {
    if (isAnonim) {
      final parts = <String>[];
      if (semester.isNotEmpty) parts.add('Semester $semester');
      if (jurusan.isNotEmpty) parts.add(jurusan);
      return parts.isEmpty ? 'Anonim' : parts.join(' · ');
    }
    return nim;
  }
}
