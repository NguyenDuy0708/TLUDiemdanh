import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/api_constants.dart';

class AuthService {
  static const String _sessionKey = 'session_id';
  static const String _usernameKey = 'username';
  static const String _roleKey = 'role';

  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final sessionId = data['session_id'];
        final role = data['role'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionKey, sessionId);
        await prefs.setString(_usernameKey, username);
        await prefs.setString(_roleKey, role);

        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final sessionId = await getSessionId();
      if (sessionId != null) {
        await http.post(
          Uri.parse('${ApiConstants.baseUrl}${ApiConstants.logout}'),
          headers: {'session-id': sessionId},
        );
      }
    } catch (e) {
      print('Logout error: $e');
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.remove(_usernameKey);
      await prefs.remove(_roleKey);
    }
  }

  Future<String?> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionKey);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  Future<bool> isLoggedIn() async {
    final sessionId = await getSessionId();
    return sessionId != null;
  }
}
