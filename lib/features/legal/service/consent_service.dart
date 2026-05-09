import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the user has explicitly accepted the Privacy Policy.
///
/// The key is versioned (`_v1`) so that a future policy revision can
/// require re-acceptance by bumping the version suffix.
class ConsentService {
  static const _key = 'privacy_policy_accepted_v1';

  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
