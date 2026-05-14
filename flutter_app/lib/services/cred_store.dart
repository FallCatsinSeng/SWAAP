import 'package:shared_preferences/shared_preferences.dart';

/// Handles secure local persistence of user credentials using SharedPreferences.
///
/// Keys are prefixed with `swaap_` to avoid collisions with other packages.
class CredStore {
  CredStore._(); // prevent instantiation

  static const _kUser = 'swaap_user';
  static const _kPass = 'swaap_pass';
  static const _kBase = 'swaap_base';
  // _kApi intentionally removed — API URL is always determined at runtime

  /// Saves credentials to local storage.
  static Future<void> save({
    required String user,
    required String pass,
    required String base,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUser, user);
    await p.setString(_kPass, pass);
    await p.setString(_kBase, base);
    // Remove stale API URL if it exists from old versions
    await p.remove('swaap_api');
  }

  /// Loads credentials from local storage.
  ///
  /// Returns `null` if no valid credentials are stored.
  static Future<Map<String, String>?> load() async {
    final p = await SharedPreferences.getInstance();
    // Migrate: remove stale API URL saved by old versions
    await p.remove('swaap_api');
    final u = p.getString(_kUser);
    final pw = p.getString(_kPass);
    if (u == null || u.isEmpty || pw == null || pw.isEmpty) return null;
    return {
      'user': u,
      'pass': pw,
      'base': p.getString(_kBase) ?? '',
    };
  }

  /// Clears all stored credentials.
  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }
}
