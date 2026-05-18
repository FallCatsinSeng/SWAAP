/// Represents an active attendance (presensi) entry for a course.
class PresensiCourse {
  final int idKrs;
  final int yangKe;
  final int idJadwal;
  final int hibrid;
  final String namaMK;
  final String perkuliahan;
  final String ketPerkuliahan;
  final bool hadir;

  const PresensiCourse({
    required this.idKrs,
    required this.yangKe,
    required this.idJadwal,
    required this.hibrid,
    required this.namaMK,
    required this.perkuliahan,
    required this.ketPerkuliahan,
    this.hadir = false,
  });

  factory PresensiCourse.fromJson(Map<String, dynamic> j) => PresensiCourse(
        idKrs: (j['id_krs'] ?? 0) as int,
        yangKe: (j['yang_ke'] ?? 0) as int,
        idJadwal: (j['id_jadwal'] ?? 0) as int,
        hibrid: (j['hibrid'] ?? 0) as int,
        namaMK: '${j['nama_mk'] ?? ''}',
        perkuliahan: '${j['perkuliahan'] ?? ''}',
        ketPerkuliahan: '${j['ket_perkuliahan'] ?? ''}',
        hadir: (j['hadir'] as bool?) ?? false,
      );
}
