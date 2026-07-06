import 'package:ezbiz/Consts/consts.dart';
import 'package:ezbiz/pages/login.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Map<String, String>> authHeaders() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');

  return {
    "Content-Type": "application/json",
    if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
  };
}

Future<void> clearAllAuthPrefs() async {
  await AuthStorage.clearAll();
}

/// Call from any 401 response handler. Clears stored credentials and
/// navigates the user back to the login screen from anywhere in the app.
void clearAuthAndNavigateToLogin() {
  clearAllAuthPrefs().then((_) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
      (route) => false,
    );
  });
}
