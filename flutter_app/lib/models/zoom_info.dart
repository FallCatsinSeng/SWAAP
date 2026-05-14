/// Zoom meeting information extracted from a schedule room string.
class ZoomInfo {
  final String meetingId;
  final String password;
  final String roomOnly;

  const ZoomInfo({
    required this.meetingId,
    required this.password,
    required this.roomOnly,
  });

  /// Returns true if this item has a valid Zoom meeting ID.
  bool get hasZoom => meetingId.isNotEmpty;

  /// Parses Zoom meeting info from a room string.
  ///
  /// Supports two formats:
  /// - URL: `https://zoom.us/j/123?pwd=abc`
  /// - Plain text: `687 529 1614 swu12345`
  static ZoomInfo parse(String room) {
    final idx = room.toLowerCase().indexOf('link zoom');
    if (idx < 0) {
      return ZoomInfo(meetingId: '', password: '', roomOnly: room.trim());
    }

    final roomOnly = room.substring(0, idx).trim();
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
        return ZoomInfo(
          meetingId: mid,
          password: uri.queryParameters['pwd'] ?? '',
          roomOnly: roomOnly,
        );
      }
    }

    // Plain text format: "687 529 1614 swu12345" or "6875291614 swu12345"
    final nums =
        RegExp(r'[\d\s]+').firstMatch(rest)?.group(0)?.trim() ?? '';
    final afterNums = rest.substring(nums.length).trim();
    return ZoomInfo(meetingId: nums, password: afterNums, roomOnly: roomOnly);
  }
}
