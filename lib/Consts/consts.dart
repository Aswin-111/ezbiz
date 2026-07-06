import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// const baseUrl = 'https://txxp36hr-8080.inc1.devtunnels.ms';
const baseUrl = 'https://ezbiz.co.in/ezbizserver'; // production url

final navigatorKey = GlobalKey<NavigatorState>();

class AuthStorage {
  static const _kToken = 'auth_token';
  static const _kSessionId = 'session_id';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  static Future<void> saveSessionId(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionId, sessionId);
  }

  static Future<String?> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSessionId);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kSessionId);
    await prefs.remove('comp_code');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_type');
    await prefs.remove('login_response');
  }
}

