/// Represents a single schedule (jadwal) entry from the academic portal.
class JadwalItem {
  final int rowId;
  final String meeting;
  final String date;
  final String time;
  final String room;
  final String method;
  final String courseName;
  final String lecturer;

  const JadwalItem({
    required this.rowId,
    required this.meeting,
    required this.date,
    required this.time,
    required this.room,
    required this.method,
    required this.courseName,
    required this.lecturer,
  });

  /// Parses the start [DateTime] from the [date] and [time] fields.
  DateTime? get startDT {
    try {
      final d = date.split('-');
      final t = time.split('-')[0].trim().replaceAll('.', ':').split(':');
      return DateTime(
        int.parse(d[2]),
        int.parse(d[1]),
        int.parse(d[0]),
        int.parse(t[0]),
        int.parse(t[1]),
      );
    } catch (_) {
      return null;
    }
  }

  /// Parses the end [DateTime] from the [date] and [time] fields.
  DateTime? get endDT {
    try {
      final d = date.split('-');
      final t = time
          .split('-')[1]
          .trim()
          .split(' ')[0]
          .replaceAll('.', ':')
          .split(':');
      return DateTime(
        int.parse(d[2]),
        int.parse(d[1]),
        int.parse(d[0]),
        int.parse(t[0]),
        int.parse(t[1]),
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns true if this schedule is currently ongoing.
  bool get isOngoing {
    final now = DateTime.now();
    final s = startDT;
    final e = endDT;
    return s != null && e != null && now.isAfter(s) && now.isBefore(e);
  }

  /// Returns true if this schedule is in the future.
  bool get isUpcoming {
    final s = startDT;
    return s != null && DateTime.now().isBefore(s);
  }

  factory JadwalItem.fromJson(Map<String, dynamic> j) => JadwalItem(
        rowId: (j['row_id'] ?? 0) as int,
        meeting: '${j['meeting'] ?? ''}',
        date: '${j['date'] ?? ''}',
        time: '${j['time'] ?? ''}',
        room: '${j['room'] ?? ''}',
        method: '${j['method'] ?? ''}',
        courseName: '${j['course_name'] ?? ''}',
        lecturer: '${j['lecturer'] ?? ''}',
      );
}
