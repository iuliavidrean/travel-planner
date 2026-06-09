import 'package:shared_preferences/shared_preferences.dart';

// Session service
class SessionService {
  static const String tokenKey = 'auth_token';

  // salvarea token-ului dupa logare in sesiune
  static Future<void> setToken(String newToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, newToken);
  }

  // citirea tokenului cand accesam resursele protejate
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  // stergerea tokenului dupa logout
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
  }

  // verificare daca utilizatorul este logat
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
