// lib/services/auth_service.dart
import 'package:shared_preferences/shared_preferences.dart';

import '../db/db_helper.dart';

class AuthService {
  static String? _loggedInUser;
  static String? get currentUser => _loggedInUser;
  static bool get isLoggedIn => _loggedInUser != null;

  static Future<bool> login(String username, String password) async {
    final rows = await DBHelper.instance.query(
      'SELECT id FROM users WHERE username = :p0 AND password = :p1 LIMIT 1',
      [username, password],
    );
    if (rows.isNotEmpty) {
      _loggedInUser = username;
      return true;
    }
    return false;
  }

  static void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _loggedInUser = null;
  }
}
