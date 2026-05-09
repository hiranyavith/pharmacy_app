// lib/services/auth_service.dart
import '../db/db_helper.dart';

class AuthService {
  static String? _loggedInUser;
  static String? get currentUser => _loggedInUser;
  static bool    get isLoggedIn  => _loggedInUser != null;

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

  static void logout() => _loggedInUser = null;
}
