import 'package:shared_preferences/shared_preferences.dart';

/// Handles secure local persistence of user credentials using SharedPreferences.
///
/// Keys are prefixed with `swaap_` to avoid collisions with other packages.
class CredStore {
  CredStore._(); // prevent instantiation

  static const _kUser = 'swaap_user';
  static const _kPass = 'swaap_pass';
  static const _kBase = 'swaap_base';
  static const _kApi = 'swaap_api';

  /// Saves credentials to local storage.
  static Future<void> save({
    required String user,
    required String pass,
    required String base,
    required String api,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUser, user);
    await p.setString(_kPass, pass);
    await p.setString(_kBase, base);
    await p.setString(_kApi, api);
  }

  /// Loads credentials from local storage.
  ///
  /// Returns `null` if no valid credentials are stored.
  static Future<Map<String, String>?> load() async {
    final p = await SharedPreferences.getInstance();
    final u = p.getString(_kUser);
    final pw = p.getString(_kPass);
    if (u == null || u.isEmpty || pw == null || pw.isEmpty) return null;
    return {
      'user': u,
      'pass': pw,
      'base': p.getString(_kBase) ?? '',
      'api': p.getString(_kApi) ?? '',
    };
  }

  /// Clears all stored credentials.
  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }
}
