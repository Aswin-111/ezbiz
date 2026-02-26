

//Url

//const baseUrl = 'https://dorakart.co/api';
import 'package:shared_preferences/shared_preferences.dart';

// const baseUrl = 'https://txxp36hr-8080.inc1.devtunnels.ms';
const baseUrl = 'https://ezbiz.co.in/ezbizserver';// production url


class AuthStorage {
  static const _kToken = 'auth_token';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
  }
}

